# Copyright 2020 Manuel Pöll
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

getLatestCIBuildNumber() {
    local -r BUILD_TARGET="$1"

    local -r BUILD_NUMBER="$(curl "https://ci.android.com/builds/branches/aosp-master/status.json" \
        | jq -r ".targets[] | select(.name | contains(\"${BUILD_TARGET}\")) | .last_known_good_build" \
    )"

    echo "$BUILD_NUMBER"
}
