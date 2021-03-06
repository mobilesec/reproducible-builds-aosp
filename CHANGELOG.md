
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
