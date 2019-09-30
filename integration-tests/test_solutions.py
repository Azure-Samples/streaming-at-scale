import os
import json
import subprocess
import glob

import pytest
from flaky import flaky


# Generate parametric tests by parsing test_spec.json files in each solution directory
def pytest_generate_tests(metafunc):
    stage = metafunc.config.getoption("stage")
    test_spec_files = glob.glob("../*/test_spec.json")
    test_specs = []
    test_ids = []
    for f in sorted(test_spec_files):
        with open(f) as fd:
            new_specs = json.load(fd)
            for spec in new_specs:
                if spec["stage"] == stage:
                    spec["folder"] = os.path.basename(os.path.dirname(f))
                    test_specs.append(spec)
                    test_id = "{} {} ({})".format(
                        spec["short"], spec["folder"], " ".join(spec["extra_args"]))
                    test_ids.append(test_id)
    argnames = ["folder", "short", "steps",
                "minutes", "throughput", "extra_args"]
    metafunc.parametrize(
        argnames,
        [[spec[name] for name in argnames] for spec in test_specs],
        ids=test_ids
    )


class TestSolutions():

    # Test the creation of a solution.
    # Flaky is used to rerun tests that may fail because of transient cloud issues.
    @flaky(max_runs=3)
    def test_solution(self, folder, steps, minutes, throughput, extra_args):
        print(self, folder, steps, minutes, throughput, extra_args)
        cmd = ["./create-solution.sh",
               "-d", self.rg,
               "-s", steps,
               "-l", os.environ['LOCATION'],
               *extra_args]
        env = dict(os.environ, REPORT_THROUGHPUT_MINUTES=minutes)
        subprocess.run(cmd, env=env, cwd="../" + folder, check=True)

    @pytest.fixture(autouse=True)
    def run_around_tests(self, short):
        self.rg = os.environ['RESOURCE_GROUP_PREFIX'] + short
        # Delete solution resource group if already exists
        subprocess.run(["./check-resource-group.sh", self.rg], check=True)
        # Run test function
        yield
        # Delete solution resource group
        subprocess.run(["./delete-resource-group.sh", self.rg], check=True)
