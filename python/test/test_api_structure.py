"""Characterize the working-record model before contract-driven implementation changes.

These tests preserve existing Python behavior, not a new Swift-shaped API. They
use synthetic in-memory data and mocked file-writing boundaries, without networking.
"""

from datetime import date, datetime, timezone
from unittest import TestCase, mock

from pydicom.dataset import Dataset

from dicom4ortho.controller import OrthodonticController
from dicom4ortho.m_orthodontic_photograph import (
    OrthodonticPhotograph, OrthodonticSeries, OrthodonticStudy,
)


class TestWorkingRecord(TestCase):
    """C01–C04: an editable partial document, not mandatory one-shot conversion."""

    def test_empty_record_and_dataset_access_retain_the_same_working_state(self):
        photo = OrthodonticPhotograph()
        dataset = photo.to_dataset()
        self.assertIs(dataset, photo.to_dataset())
        self.assertNotIn('PixelData', dataset)
        photo.patient_lastname = 'Example'
        photo.patient_firstname = 'Alex'
        self.assertEqual(dataset.PatientName, 'Example^Alex')
        photo.patient_firstname = 'Morgan'
        self.assertEqual(dataset.PatientName, 'Example^Morgan')
        dataset.PatientID = 'direct-edit'
        self.assertEqual(photo.patient_id, 'direct-edit')

    def test_image_free_template_applies_profile_without_writing_or_inventing_pixels(self):
        photo = OrthodonticPhotograph(image_type='EV-01')
        dataset = photo.to_dataset()
        self.assertEqual(photo.type_keyword, 'EV01')
        self.assertTrue(photo.is_extraoral())
        self.assertFalse(photo.is_intraoral())
        self.assertIn('AnatomicRegionSequence', dataset)
        self.assertNotIn('PixelData', dataset)
        self.assertIsNone(photo.output_image_filename)

    def test_unresolved_type_does_not_discard_independently_supplied_context(self):
        for image_type in (None, 'unknown'):
            with self.subTest(image_type=image_type):
                photo = OrthodonticPhotograph(
                    image_type=image_type, acquisition_datetime='2026-07-14T12:00:00+00:00',
                    treatment_event_type='PatientRegistration', treatment_event_date='2026-07-14')
                context = photo.to_dataset().AcquisitionContextSequence
                self.assertEqual(len(context), 2)
                self.assertEqual(context[0].ConceptCodeSequence[0].CodeValue, '184047000')
                self.assertEqual(context[1].NumericValue, 0)
                self.assertNotIn('AnatomicRegionSequence', photo.to_dataset())

    def test_code_edit_is_distinct_from_profile_application_and_preserves_other_items(self):
        photo = OrthodonticPhotograph()
        unrelated = Dataset()
        unrelated.CodeValue = 'unrelated'
        unrelated.CodingSchemeDesignator = '99TEST'
        unrelated.CodeMeaning = 'Unrelated code'
        photo.to_dataset().ViewCodeSequence = [unrelated]
        for keyword in ('EV01', 'EV08'):
            code = Dataset()
            code.CodeValue = keyword
            code.CodingSchemeDesignator = '99TEST'
            code.CodeMeaning = 'Synthetic photograph type'
            code.ContextGroupExtensionCreatorUID = '1.2.826.0.1.3680043.10.123'
            photo.image_type_code_dataset = code
            self.assertEqual(photo.image_type_code_dataset.CodeValue, keyword)
            self.assertEqual(photo.to_dataset().ViewCodeSequence[0].CodeValue, 'unrelated')
            self.assertEqual(len(photo.to_dataset().ViewCodeSequence), 2)
            self.assertNotIn('AnatomicRegionSequence', photo.to_dataset())
        photo.set_dicom_attributes_by_type_keyword()
        self.assertEqual(photo.type_keyword, 'EV08')
        self.assertIn('AnatomicRegionSequence', photo.to_dataset())

    def test_explicit_acquisition_and_progress_survive_repeated_preparation(self):
        photo = OrthodonticPhotograph(image_type='EV08')
        photo.set_time_captured(datetime(2026, 7, 14, 12, 30, tzinfo=timezone.utc))
        photo.set_treatment_progress_from_date('PatientRegistration', date(2026, 7, 1))
        for _ in range(2):
            photo.prepare()
            dataset = photo.to_dataset()
            self.assertEqual(str(dataset.AcquisitionDate), '20260714')
            self.assertEqual(str(dataset.ContentDate), '20260714')
            self.assertEqual(dataset.AcquisitionContextSequence[-1].NumericValue, 13)


class TestPreparationIdentity(TestCase):
    """C06/C08: complete missing hierarchy IDs without identity churn or SOP replacement."""

    def test_prepare_allocates_missing_hierarchy_identity_and_then_preserves_it(self):
        photo = OrthodonticPhotograph()
        sop_uid = photo.to_dataset().SOPInstanceUID
        self.assertIsNone(photo.study_instance_uid)
        self.assertIsNone(photo.series_instance_uid)
        photo.prepare()
        first = (photo.study_instance_uid, photo.series_instance_uid, sop_uid)
        self.assertEqual(len(set(first)), 3)
        photo.prepare()
        self.assertEqual((photo.study_instance_uid, photo.series_instance_uid,
                          photo.to_dataset().SOPInstanceUID), first)

    def test_prepare_repairs_colliding_hierarchy_uids_without_replacing_sop_identity(self):
        photo = OrthodonticPhotograph()
        sop_uid = photo.to_dataset().SOPInstanceUID
        photo.study_instance_uid = sop_uid
        photo.series_instance_uid = sop_uid
        with self.assertLogs('dicom4ortho.model', level='WARNING') as captured:
            photo.prepare()
        self.assertTrue(any('Generating new ones' in message for message in captured.output))
        self.assertEqual(photo.to_dataset().SOPInstanceUID, sop_uid)
        self.assertEqual(len({photo.study_instance_uid, photo.series_instance_uid, sop_uid}), 3)


class TestWorkingRecordGroups(TestCase):
    """C07/C10: grouping and adapters operate on the caller's actual records."""

    def test_grouping_retains_live_children_and_propagates_at_existing_boundaries(self):
        first = OrthodonticPhotograph(study_instance_uid='1.2.3', series_instance_uid='1.2.4')
        second = OrthodonticPhotograph(study_instance_uid='1.2.3', series_instance_uid='1.2.4')
        series = OrthodonticSeries(uid='1.2.5', description='Shared series')
        study = OrthodonticStudy(uid='1.2.6')
        with mock.patch.object(first, 'save') as save_first, \
             mock.patch.object(second, 'save') as save_second:
            series.add(first)
            series.add(second)
            self.assertEqual(len(series), 2)
            self.assertIs(list(series)[0], first)
            self.assertIs(list(series)[1], second)
            self.assertEqual(first.series_instance_uid, '1.2.4')
            first.patient_id = 'edited-after-add'
            self.assertEqual(series.Photos[0].patient_id, 'edited-after-add')
            study.add(series)
            self.assertEqual(len(study), 1)
            self.assertIs(list(study)[0], series)
            self.assertEqual(series.StudyUID, study.UID)
            self.assertEqual(first.study_instance_uid, '1.2.3')
            save_first.assert_not_called()
            save_second.assert_not_called()
            series.save(filename_prefix='synthetic')
            for index, photo in enumerate((first, second), start=1):
                self.assertEqual(photo.study_instance_uid, study.UID)
                self.assertEqual(photo.series_instance_uid, series.UID)
                self.assertEqual(photo.series_description, 'Shared series')
                self.assertEqual(photo.output_image_filename, f'synthetic_{index}.dcm')
            save_first.assert_called_once_with()
            save_second.assert_called_once_with()

    def test_controller_conversion_returns_its_working_record_without_saving(self):
        controller = OrthodonticController()
        metadata = {'input_image_filename': 'synthetic.jpg', 'image_type': 'EV01'}
        # Source ingestion is tested elsewhere; this isolates adapter state/path behavior.
        with mock.patch.object(OrthodonticPhotograph, 'set_image'), \
             mock.patch.object(OrthodonticPhotograph, 'set_exif_tags'), \
             mock.patch.object(OrthodonticPhotograph, 'save') as save:
            photo = controller.convert_image_to_dicom4orthograph(metadata)
            self.assertIs(photo, controller.photo)
            self.assertEqual(metadata['output_image_filename'], 'synthetic.dcm')
            self.assertEqual(photo.output_image_filename, 'synthetic.dcm')
            save.assert_not_called()
