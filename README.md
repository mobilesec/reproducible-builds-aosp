
# Simple Opinionated AOSP builds by an external Party (SOAP)

![SOAP logo](branding/soap-icon-v2.svg "SOAP logo")

This project aims to build AOSP in a reproducible manner and identify differences to the reference builds provided by Google. As reference builds we intend to track a selection of the following:
* [Factory images](https://developers.google.com/android/images) for phones by Google
* Generic system images as provided by [Android CI](https://ci.android.com)

This project enables the broader Android community, as well as any interested third parties, to track differences differences between AOSP and official Google builds. Furthermore it can act as basis for future changes improving the reproducibility of Android.

## Usage instruction

Depending on your preferred runtime environment, the following setup instructions and associated run-instructions need to be performed. In all cases, make sure you acquire a copy of [this repository](https://github.com/mobilesec/reproducible-builds-aosp).

### Direct Script Invocation

1. Start with a Debian-based environment (at least Debian 10, or Ubuntu 18.04) running on a x86 architecture.
2. Prepare a build environment by executing all scripts under `scripts/shared/setup`, except `04_config-profile-for-docker.sh`, in proper sequence. The order is indicated by the number in the first two characters of the file name and none of the scripts require parameters. Note that the executing user needs permission to install new APT packages.

Setup is now finished. You can now invoke one of the following master scripts performing the AOSP build and SOAP analysis process:

- `run-host-device.sh`: Build a AOSP device target and compare against the matching Google factory image. Parameters need to be set via environment variables.

### Docker Container

1. Start with any x86-based environment capable of running Docker containers.
2. Build the Docker container by executing `build-docker-image.sh`

Setup is now finished. You can now invoke one of the following master scripts performing the AOSP build and SOAP analysis process:

- `run-docker-device-fixed.sh`: Build a AOSP device target and compare against the matching Google factory image. Parameters are hardcoded in the script, change as needed.
- `run-docker-generic-latest.sh`: Build a AOSP generic system images (GSI) and compare against the GSI build from Google. The `BUILD_NUMBER` parameter is the latest valid build from the Android CI dashboard, all other other parameters are hardcoded.

### Jenkins Server

1. Start with a Debian-based environment (at least Debian 10, or Ubuntu 18.04) running on a x86 architecture.
2. Run `jenkins/setup/01_install-jenkins` to install Jenkins, note that the executing user needs permission to install new APT packages. Alternatively perform the Jenkins installation on your own.
3. Invoke `jenkins/setup/02_create_pipelines` to import the two Jenkins pipelines found in `jenkins`. As an alternative, one may create the parameterized pipelines via the GUI, refer to the `.Jenkinsfile` files for the build scripts and be sure to create all parameters required for them.

Setup is now finished. You can now invoke one of the following master scripts performing the AOSP build and SOAP analysis process:

- `run-jenkins-device-fixed.sh`: Build a AOSP device target and compare against the matching Google factory image. Parameters are hardcoded in the script, change as needed.
- `run-jenkins-generic-latest.sh`: Build a AOSP generic system images (GSI) and compare against the GSI build from Google. The `BUILD_NUMBER` parameter is the latest valid build from the Android CI dashboard, all other other parameters are hardcoded.

## Parameters

### Device builds

- `AOSP_REF`: Branch or tag in the AOSP codebase, refer to [Source code tags and builds](https://source.android.com/setup/start/build-numbers\#source-code-tags-and-builds) for a list. Specifically refer to the `Tag` column, e.g. `android-10.0.0_r40`.
- `BUILD_ID`: Specific version of AOSP, corresponds to a certain tag. Refer to the `Build` column in the same [Source code tags and builds](https://source.android.com/setup/start/build-numbers\#source-code-tags-and-builds) table, e.g. `QQ3A.200705.002`.
- `DEVICE_CODENAME`: Internal code name for the device, see the [Fastboot instructions](https://source.android.com/setup/build/running\#booting-into-fastboot-mode) for a list mapping branding names to the codenames. For example, the `Pixel 3 XL` branding name has the codename `crosshatch`.
- `RB_BUILD_TARGET`: Our build target as chosen in `lunch` (a helper function of AOSP), consisting of a tuple (`TARGET_PRODUCT` and `TARGET_BUILD_VARIANT`) combined via a dash. The [Choose a target](https://source.android.com/setup/build/building\#choose-a-target) section provides documentation for these. AOSP offers `TARGET_PRODUCT` values for each device with an `aosp\_` prefix. E.g a release build of the previously mentioned `Pixel 3 XL` device would be defined as `aosp_crosshatch-user`.
- `GOOGLE_BUILD_TARGET`: Very similar to `RB_BUILD_TARGET`, except that this represents Google's build target. Note that factory images provided by Google use a non-AOSP `TARGET_PRODUCT` variable. E.g a release build by Google for our running example would be defined as `crosshatch-user`.

### Generic builds

- `BUILD_NUMBER`: Build number used by Google in the [Android CI Dashboard](https://ci.android.com).
- `BUILD_TARGET`: Build target consisting of a tuple (`TARGET_PRODUCT` and `TARGET_BUILD_VARIANT`) combined via a dash. Refer to the [Android CI Dashboard](https://ci.android.com) for available GSI targets.

## Reports

Once the build and subsequent analysis finishes, one can find the uncovered differences in `$RB_AOSP_BASE/diff` in a folder named according to your build parameters. Optionally one can set the environment variable `RB_AOSP_BASE` ahead of the master script invocation to tell SOAP the base location where all (temporary and non-temporary) files should be placed under. If not specified, it defaults to `${HOME}/aosp`. Refer to [Hardware requirements](https://source.android.com/setup/build/requirements\#hardware-requirements) for disk space demand.

When navigating the SOAP reports with a browser, start at `$RB_AOSP_BASE/diff/reports-overview.html`. The links contain the AOSP source tag (or Google build id), build target and build environment for both the reference AOSP build and ours. For each of these we provide the following reports for all analyzed build artifacts:

- ***Detailed Reports*** Show unified diffs between builds, while
- ***Diff Change Visualizations*** provides a simple treemap visualization highlighting the distribution of changes within an artefact.

## Background and affiliation

Project by the Institute of Networks and Security at the Johannes Kepler University, details can be found at [android.ins.jku.at](https://android.ins.jku.at/reproducible-builds/). Developed by Manuel Pöll as bachelor project. Details, theoretical background and interpretation of several SOAP reports can be found in the [bachelor thesis](https://github.com/mobilesec/reproducible-builds-aosp/raw/master/background-work/An-Investigation-Into-Reproducible-Builds-for-AOSP.pdf). SOAP Reports run by the JKU INS institute can be found [here](https://android.ins.jku.at/soap/report-overview.html).

## License

Copyright 2020 Manuel Pöll

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
