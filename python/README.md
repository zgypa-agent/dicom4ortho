# dicom4ortho for Python — 0.5.4-dev

Python library and CLI for creating orthodontic DICOM photographs. See the
[project introduction](https://github.com/open-ortho/dicom4ortho#introduction) for
the shared standards and clinical scope. This implementation uses
[pydicom](https://pydicom.github.io/),
[pynetdicom](https://pydicom.github.io/pynetdicom/), and
[Pillow](https://python-pillow.org/).

## Installation

Requires Python 3.10 or newer:

```sh
pip install dicom4ortho
```

For development, run from the **repository root**; packaging lives in `python/`:

```sh
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -e "./python[dev]"
```

The development dependencies also provide the shared terminology generator's
`rdflib` RDF/XML parser. Python is needed for that maintenance tool, not for Swift
builds or runtime.

## Library API

Python builds a photograph by constructing `OrthodonticPhotograph(**metadata)`.
It does **not** have a `materialize()` method. The photograph holds a pydicom
dataset; `save()` writes it separately. The controller offers convenience methods
such as `convert_image_to_dicom4orthograph(metadata)`, returning that same model.

```python
from dicom4ortho.m_orthodontic_photograph import OrthodonticPhotograph

photo = OrthodonticPhotograph(
    input_image_filename="photograph.jpg",
    image_type="EV01",
    patient_id="synthetic-001",
    patient_firstname="Alex",
    patient_lastname="Example",
)
photo.save("photograph.dcm")
```

`input_image_bytes` supports in-memory encoded images with
`input_image_filename=None`. The model also supports image-type templates and
identification, worklist metadata, study/series helpers, and network delivery.
These are not all implemented by the Swift port; see the
[API comparison](../apple/Documentation/APIParity.md).
The older [Python API/usage documentation](https://open-ortho.github.io/dicom4ortho/)
is maintained on the repository's `gh-pages` branch.

### Treatment progress

Treatment progress is an elapsed-day offset from a clinical event. Supply
`treatment_event_type` and `treatment_event_date`; canonical events are
`PatientRegistration`, `OrthodonticTreatmentStarted`, and
`OrthodonticTreatmentStopped`. The effective acquisition date is explicit
`acquisition_datetime`, falling back to EXIF `DateTimeOriginal`. Editing timestamps
and content dates are not substitutes. Missing acquisition dates, future events,
and incomplete/conflicting progress metadata are rejected; zero days is valid.

The days-based API and older aliases remain deprecated until version 2. See the
[compatibility notes](docs/TERMINOLOGY.md) and
[usage examples](https://open-ortho.github.io/dicom4ortho/usage.html#orthodontic-treatment-progress).

### Practice personnel

`dental_provider_firstname`/`dental_provider_lastname` identify the responsible
orthodontist or dentist and populate `PhysiciansOfRecord`.
`operator_firstname`/`operator_lastname` identify the person who acquired the image
and populate `OperatorsName`.

An actual referring physician is copied from `ReferringPhysicianName` in a Modality
Worklist. The requesting physician remains part of the worklist order and is linked
through request identifiers, not copied into the baseline VL Photographic Image IOD.

## Command-line usage

The CLI accepts a CSV containing image paths and metadata:

```sh
dicom4ortho python/examples/input_from.csv
dicom4ortho list-image-types
d4o_generate  # generate a DICOM UID under the configured root
```

Run the example from the repository root. Image paths are relative to the CSV;
see the [runnable example](examples/README.md). Passing a single image and metadata
directly as CLI arguments is not implemented.

### Optional validation with dicom3tools

The CLI's `--validate` option wraps
[dicom3tools](https://www.dclunie.com/dicom3tools.html) for debugging. It is not a
runtime requirement. Install it separately and configure `DICOM3TOOLS_PATH` in
`dicom4ortho/config.py`. The project's Nix development shell provides `dciodvfy`.

## Development and tests

All commands below run from the repository root:

```sh
make lint
PYTHONPATH=python python -m unittest test.test_models
PYTHONPATH=python python -m unittest discover -s python/test -t python
make test       # starts/stops Orthanc using Docker Compose, then runs the suite
python -m build python --outdir dist # wheel and source distribution in root dist/
make build      # lint, full tests (including Docker), then build
```

The test framework is `unittest`; `pytest python/test/test_cli.py` also works.
Tests resolve fixtures relative to their modules. Explicit discovery prioritizes
the repository's `test` package over Python's standard-library package of that name.

E2E tests require Orthanc. Without `make test`, manage it explicitly:

```sh
docker compose -f python/test/docker-compose.yml up -d
PYTHONPATH=python python -m unittest test.test_e2e
docker compose -f python/test/docker-compose.yml down
```

With an existing Orthanc mock, `make test COMPOSE=true` skips only Compose lifecycle
commands. Tests still require localhost HTTP 8202 and DIMSE 4242; forward those ports
when the service is in another container. This does not skip network tests.

Make invokes tools through `python3` by default. Select another interpreter with
`make PYTHON="$PWD/.venv/bin/python" build`. `make help` lists additional targets,
including clean, install-dev, and deploy. `make build` uses committed terminology
without refreshing it. Shared `update_codes`/`check_codes` commands affect **both**
ports; see the [shared maintenance contract](../README.md#shared-terminology).

### Packaging and environment

`python/pyproject.toml`, `MANIFEST.in`, `.pylintrc`, `.bumpversion.cfg`, and `Makefile`
belong to this implementation. The root Makefile includes Python's recipes, so
`make` commands still run from the repository root. Invoke version bumping there
with `bumpversion --config-file python/.bumpversion.cfg ...`.

Setuptools discovers only `dicom4ortho*` beside this manifest: the installed module
is `dicom4ortho`, not `python`. Both wheel and source archive build independently
from this directory. From inside `python/`, `pip install -e ".[dev]"` and
`python -m build` work without root Python packaging shims. The distribution carries
a copy of the project MIT license; a repository test ensures the copies match.

Python distributions include their own offline resources, not Swift artifacts or
repository-wide generator tooling. The source archive omits repository-only tests
(development environment, generator, layout, API parity inventory, and cross-port bundles); run these
from a full Git checkout. Other Python tests/fixtures and examples remain included.

The optional `nix develop .#python` shell (also the default for `nix develop`)
creates/updates `.venv`, installs development dependencies,
and refreshes the editable mapping. Virtual-environment scripts contain absolute
paths: if the checkout moves, preserve and recreate the environment. The shell
refuses stale activation paths and does not delete the old environment:

```sh
deactivate
mv .venv ".venv.old-$(date +%Y%m%d-%H%M%S)"
nix develop
```

Startup guidance also explains the separate Swift shell; it does not wait for
input, so `nix develop .#python --command make lint` remains non-interactive.

## Implementation documentation

- [Class diagram](docs/class_diagram.puml)
- [Terminology compatibility and historical validation](docs/TERMINOLOGY.md)
- [Release checklist](docs/RELEASING.md)
- [Known issues](https://github.com/open-ortho/dicom4ortho/issues)

Python release versioning and PyPI publication are described in the checklist;
they do not qualify the incomplete Swift port. The project is distributed under
the [MIT License](https://github.com/open-ortho/dicom4ortho/blob/master/LICENSE).
