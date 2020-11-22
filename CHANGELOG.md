
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
