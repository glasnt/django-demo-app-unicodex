#!/bin/bash -eu
#
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/sh
set -e

echo "📄 Make configurations"
cat << EOF > .env
SECRET_KEY=secret
DATABASE_URL=sqlite:///db.sqlite3
SUPERUSER=admin
SUPERPASS=admin
EOF

echo "🔧 Install testing suite"
pip install -r .cloudbuild/test/requirements.txt

echo "🧪 test"
coverage run --source '.' manage.py test  --exclude external

echo "📋 generate report"
coverage html
