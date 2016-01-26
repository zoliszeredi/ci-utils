"""
Prints the score difference between two pylint json files

TODO: Generate a JUNIT xml file with the new messages and consider the
      errors as failed tests

"""

import xml.etree.cElementTree as ET
import json
import sys


def compare(new, old):
    def read_json(path):
        with open(path, 'r') as fp:
            return json.loads(fp.read())

    def score(data):
        def by_type(message_type):
            return [x for x in data if x['type'] == message_type]

        def count(message_type):
            return len(by_type(message_type))

        return 10.0 - (count('warning')+ count('refactor') +
                       count('convention') + count('error') * 5) / (len(data) * 10.0)

    generate_junit_xml([x for x in read_json(new) if x['type'] == 'error'])
    return score(read_json(new)) - score(read_json(old))


def generate_junit_xml(errors):
    root = ET.Element("testsuites")
    testsuite = ET.SubElement(root, "testsuite")

    for error in errors:
        options = {
            'classname': '{module}.{obj}'.format(
                module=error['module'],
                obj=error['obj'],
            ),
            'file': error['path'],
            'name': error['message'],
            'line': u'{}'.format(error['line']), # serializer dies otherwise
        }
        ET.SubElement(testsuite, "testcase", **options)
    tree = ET.ElementTree(root)
    tree.write("pylint-errors.xml")


if __name__ == '__main__':
    print compare(*sys.argv[1:3])
