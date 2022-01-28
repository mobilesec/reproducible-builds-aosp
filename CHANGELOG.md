
# 2.2.1

- Bug fix for the improved APEX detection

# 2.2.0

- Stop applying the signing adjustments to generic builds, instead simply use the raw diffstat CSV file
- Fix a bug where folders with the `.apex` string in them are incorrectly detected as APEX files

# 2.1.3

- Improve elimination of duplicate lines by moving the sorting and/duplicate elimination from the the two data sources (which can overlap in rare cases) to a combined process step for all changed files

# 2.1.2

- Proper elimination of duplicate lines via sort ensures that non-adjacent entries are not erroneously repeated and counted multiple times

# 2.1.1

- Fixed major issue where recent versions of diffstat generate quotation-escaping for file paths and break subsequent weight score computation
- Improve handling of compressed APEX files by properly excluding them from the outer image metrics

# 2.1.0

- Improved support for new Android versions (11 and 12)
  - Handle compressed APEX files (found in Android 12) correctly
  - Handle LZ4 compressed ramdisks properly (starting with Android 11)

# 2.0.2

- Fix corner case where manifest file was not in the expected place (see build `7963114` on `aosp-android12-gsi` branch)
- Add missing tool to the build docker image, needed by some versions of AOSP
- Reduce the required disk space and download size by limiting the cloned source code to the exact version that is required for the build

# 2.0.1

- Handle multi-attempts builds, i.e. those builds that produce an `attempts` folder (e.g. https://ci.android.com/builds/submitted/6174880/aosp_x86_64-eng/latest ) correctly by only considering the builds output from last attempt (in addition to the root folder artifacts)
- Improved fix for kernel permission issue
- Small improvement to webscrapping by providing an anchor at the end, ensures that overlapping build ids don't cause an error
- Fixed too finely grained bind mounts (were not properly synced from Jenkinsfile)

# 2.0.0

- Major rework of the Docker environment
  - Both build and analysis step now run in separate Docker containers and are the only supported environment
  - All docker containers are now built for and run with non-root user, simplifies run scripts
  - Split scripts from the `scripts/shared/setup` folder into according `scripts/setup-build` and `scripts/setup-analysis`
  - Write new Jenkinsfiles that perform SOAP builds and analysis via Docker
  - Various updates to all shared scripts to be compatible with an Ubuntu 14.04 based build environment. Including some specific quirks, like
    - building `otatools` ahead of main compilation,
    - fixing issue with JACK that occurs for Android 7 build,
    - build `lpunpack` conditionally, avoids errors for earlier Android versions,
    - install x86 i386 runtime support in analysis container, needed to run host utilities for older AOSP version and
    - various other small changes
  - Use diffoscope 178, fixes issue with broken symbolic links, see https://salsa.debian.org/reproducible-builds/diffoscope/-/issues/269
    - Requires jump to Ubuntu 20.04 for analysis Docker container due to python
- Sparse image improvements
  - `simg2img` is now built via the AOSP tree (`libsparse`) ahead of main build process. This ensures `simg2img` is available in all environments, even Ubuntu 14.04, and can be used to extract build information from the reference `system.img`
  - fix detection of sparse images, happens ahead of FS detection and thus works even if the file utility does not recognize Android sparse images
- Improved handling of Android boot images
  - Prefer to use `unpack_bootimg`/``unpack_bootimg.py` tool from AOSP repo, if available
  - Detection of Android boot images no longer relies on filename, now uses the file command (magic bytes). Subsequently we also detect and unpack recovery and variations of the boot image (different kernel, ...)
- Gitconfig of local user is properly copied into containers instead of fixed dummy values
- Installation of repo is now done in `/usr/local/bin`, in the same way as the docker image of AOSP does it
- Make guestfs mount more robust by providing a fallback device name (detection does not work in Ubuntu 14.04)
- Factory extraction script now distinguishes between two different codenames, some older devices require this distinction
- Hardcode additional diffoscope dependencies (as reported by `diffoscope --list-missing-tools debian` minus some trimming to accommodate minor differences between Debian and Ubuntu), this ensures the dependency list works for Ubuntu, the recommended build environment for AOSP
- Make master and setup scripts generic `sh`-scripts
- More consistent metric computation: Stop excluding `vendor.img` from device build metric computation
- Update the README for the new major release

# 1.5.0

- Complete rewrite of quantitative output, diffstat results are now further processed into 2 metrics: diff-score and weight-score
- Incorporate four build parameters that mimic values from the Google build environment, reducing the number of differences in property files
- Unpack `boot.img` into three separate files, the `bootcfg.txt`, `initrd.img` and `zImage`. This simplifies computation of the weight metric
- Major rework of the HTML index page for a single run showing both diffoscope report and our quantitative ones
- Small update the `README`
  - Remove quirk handling from scripts, only address here as common issues
- Renamed several scripts to be more semantic
- Slight update to the APT dependency list based on testing on Debian 10

# 1.4.0

- Many Improvements based on ShellCheck
- Use more appropriate file path for adjusted CSV reports

# 1.3.0

- Codify expected diffs (metadata from diffoscope excludes) and use that to
  - Generate adjusted CSV reports per image
  - And only use these number in subsequent reports (summary CSV report, hierarchy visualization)
- Simplify code and improve generation of generic CSV summary reports
- Major refactor of the generic flow that
  - closely mimic the build instruction of the Android CI (reduces potential differences, increases build speed)
  - Copy and use more images files (the ones from the `...-img-....zip`) to get a more complete picture of differences in the GSI builds
- Format files that erroneously used tabs

# 1.2.0

- Remove hard coded assumption about APEX version mismatch
- Cleaned up APT dependencies and aligned them more closely with official installation instructions
- Update host script to be consistent with Docker/Jenkins
- Default to the `userdebug` build type for GSI (changed on 26.1.2021 on [Android CI](https://ci.android.com))
- New script for running a fixed build number for the generic flow

# 1.1.0

- Perform (partial) release procedure for both generic and device targets
  - Build dist target after the main build process, this prepares the output for release (e.g. normalizing filesystem timestamps)
  - Subsequently we no longer instruct diffoscope to ignore metadata differences
- Minor web scrapping update to keep generic builds working
- Include version info and timestamp into SOAP reports
- Remove file with test data from assets folder

# 1.0.0

- **First official stable release**
- Refer to main README for general infos, usage instructions and more
