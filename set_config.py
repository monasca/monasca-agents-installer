# Copyright 2017 FUJITSU LIMITED
#
# Licensed under the Apache License, Version 2.0 (the \"License\");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an \"AS IS\" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import configparser
import sys
from jinja2 import Template
from optparse import OptionParser


def main():
    parser = OptionParser()
    parser.add_option("--tmp_config", dest = "tmp_config")
    parser.add_option("--config", dest = "config")
    parser.add_option("--input_ini", dest = "input_ini")
    parser.add_option("--monasca_log_api_url", dest = "monasca_log_api_url")
    parser.add_option("--keystone_auth_url", dest = "keystone_auth_url")
    parser.add_option("--project_name", dest = "project_name")
    parser.add_option("--username", dest = "username")
    parser.add_option("--password", dest = "password")
    parser.add_option("--user_domain_name", dest = "user_domain_name")
    parser.add_option("--project_domain_name", dest = "project_domain_name")
    parser.add_option("--hostname", dest = "hostname")

    options, args = parser.parse_args()

    in_path = options.tmp_config
    out_path = options.config
    input_ini_path = options.input_ini
    monasca_log_api_url = options.monasca_log_api_url
    keystone_auth_url = options.keystone_auth_url
    project_name = options.project_name
    username = options.username
    password = options.password
    user_domain_name = options.user_domain_name
    project_domain_name = options.project_domain_name
    hostname = options.hostname

    config_input = configparser.ConfigParser(interpolation=None)
    config_input.read(input_ini_path)

    input_config = []

    for section in config_input.sections():
        input_demensions = config_input.get(section, "add_field")
        input_path = config_input.get(section, "path")
        input_tags = config_input.get(section, "tags")

        filter_pattern = config_input.get(section, "pattern")
        filter_what = config_input.get(section, "what")
        filter_negate = config_input.get(section, "negate")

	
        input_config.append({"dimensions": input_demensions, "path": input_path,
                             "tags": input_tags, "pattern": filter_pattern, "what": filter_what,
                             "negate": filter_negate})

    output_config = {"monasca_log_api_url": monasca_log_api_url,
                     "keystone_api_url": keystone_auth_url,
                     "project_name": project_name,
                     "username": username,
                     "password": password,
                     "user_domain_name": user_domain_name,
                     "project_domain_name": project_domain_name,
                     "dimensions": hostname}

    with open(in_path, 'r') as in_file, open(out_path, 'w') as out_file:
        t = Template(in_file.read())
        out_file.write(t.render({"input": input_config, "output": output_config}))

if __name__ == '__main__':
    main()
