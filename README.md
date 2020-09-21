
Simple Opinionated AOSP builds by an external Party (SOAP)
==========================================================

![SOAP logo](branding/SOAP_icon.svg "SOAP logo")

This project aims to build AOSP in a reproducible manner and identify differences to the reference builds provided by Google. As reference builds we intend to track a selection of the following:
* [Factory images](https://developers.google.com/android/images) for phones by Google
* Generic system images as provided by [Android CI](https://ci.android.com)

This project enables the broader Android community, as well as any interested third parties, to track differences differences between AOSP and official Google builds. Furthermore it can act as basis for future changes improving the reproducibility of Android.

Reproducible Builds in General
------------------------------

Reproducible builds in general have been widely recognized as an important step for improving trust in executable binaries. More general information on reproducible builds can be found at the [website of the Reproducible Builds project](https://reproducible-builds.org/). More specifically for Android, increased reproducibility bridges the gap between source code provided by the AOSP and the factory images running on millions of Google phones today.

Project goals
-------------

Our first primary goal, ***building AOSP in a reproducible manner***, should be achieved (or at least we attempt to) by a collection of simple shell scripts that are based on the official instructions from the [Android source documentation](https://source.android.com). These will be released as open source, enabling verification of our process. Furthermore, it should allow third parties (even without the technical knowhow) to create their own Android images that match ours. We anticipate (and this appears to be the initial result of preliminary testing) that there are still some differences that can’t be trivially accounted for.

Thus, our second goal, ***analyzing the differences between our builds and reference ones***, plays an important role as well. Uncovered diffs between aforementioned builds should be made accessibly via a web interface. Furthermore we intend to aggregate these diffs (number of added/deleted lines). Such a quantitative analysis allows a big picture view of trends of this subject. Note that some differences are expected (e.g. due to signing keys), all of these instances will be documented.

Reports
-------

Report results for builds performed by the INS institute can be found [here](https://android.ins.jku.at/soap/report-overview.html). The links contain the AOSP source tag (or Google build id), build target and build environment for both the reference AOSP build and ours. For each of these we provide the following reports for all analyzed build artifacts:

- ***Detailed Reports*** Show unified diffs between builds, while
- ***Diff Change Visualizations*** provides a simple treemap visualization highlighting the distribution of changes within an artefact.
