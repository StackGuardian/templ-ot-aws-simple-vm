# Tests

Tests use the built-in OpenTofu test framework (`tofu test`, OpenTofu 1.9 or later).

| Level | Folder | What it does | Cost | When it runs |
|---|---|---|---|---|
| Unit | `tests/unit` | Plan only with mocked providers. Checks configuration and security settings. | None | Merge requests into `development` or `main`, and tags |
| Integration | `tests/integration` | Deploys real resources, checks them, destroys them. | Cloud cost while running | Tags, when cloud credentials are set (`integration-tests` job) |

In the GitLab pipeline, the `unit-tests` job also publishes the results as a JUnit test report (**Tests** tab of the pipeline and of the merge request). The script `ci/tofu-json-to-junit.py` converts the output of `tofu test -json` to JUnit XML.

## Run locally

```bash
tofu init
tofu test -test-directory=tests/unit
tofu test -test-directory=tests/integration   # needs cloud credentials
```

## Test cases

| ID | Level | Description | Status |
|---|---|---|---|
| U-01 | Unit | Default variables produce a valid plan with all default tags | done |
| U-02 | Unit | Invalid `name_prefix` is rejected | done |
| U-03 | Unit | Custom `advanced_settings.tags` are merged with the default tags | done |
| U-04 | Unit | By default no Elastic IP, instance in the private subnet, no inbound rules | done |
| U-05 | Unit | IMDSv2 is enforced (`http_tokens = "required"`) | done |
| U-06 | Unit | Root volume is encrypted | done |
| U-07 | Unit | Instance profile includes `AmazonSSMManagedInstanceCore` | done |
| U-08 | Unit | `advanced_settings.enable_public_ip = true` without `advanced_settings.allowed_ingress_cidrs` is rejected | done |
| U-09 | Unit | `advanced_settings.allowed_ingress_cidrs` containing `0.0.0.0/0` is rejected | done |
| U-10 | Unit | With public IP enabled: public subnet, Elastic IP, ingress only from the given CIDRs and ports | done |
| U-11 | Unit | VPC flow logs capture all traffic | done |
| U-12 | Unit | `advanced_settings.allowed_ingress_cidrs` broader than `/8` (for example `128.0.0.0/1`) is rejected | done |
| U-13 | Unit | A newer Amazon Linux AMI does not change the instance (no replacement on a later run) | done |
| I-01 | Integration | Default deployment: instance is running and has no public IP | done |
| I-02 | Integration | Instance registers with SSM Session Manager (waits 3 minutes) | done |
| I-03 | Integration | With `advanced_settings.enable_public_ip = true`: public IP output is set | done |

Integration tests are written but have not run against a real cloud account yet.
