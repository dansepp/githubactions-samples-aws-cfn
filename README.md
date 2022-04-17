# GitHub Actions AWS CloudFormation Samples

This repository contains a collection of CICD examples for AWS CloudFormation and GitHub Actions. Some of the workflows performing CI and/or CD are redudnant, as the intent is to illustrate various options.

## Prerequisites

### GitHub Identity Provider for AWS

A GitHub identity provider must be configured in the target AWS environment in order for GitHub Actions to successfully authenticate (using v1 of [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)). A modified version of the [sample CloudFormation template](https://github.com/aws-actions/configure-aws-credentials#sample-iam-role-cloudformation-template) is included in this repository to simplify the setup process.

### GitHub Actions secrets

The following actions secrets must be configured in the repo for the workflows to run successfully:

- **GH_ACTIONS_BUCKET**. The name of the AWS S3 bucket in the account where the sample CloudFormation templates get deployed.
- **GH_IAM_ROLE**. The AWS IAM Role ARN created by the GitHub IdP (see above).

## Research Notes

- **Reusable workflow pattern**: The [workflow_call](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onworkflow_call) capability provides an abstraction mechanism at the job level, as it essentially defines a collection of jobs as a reuable unit. In this case, the workflow being called is unaware of which workflows are calling it. When a workflow has `workflow_call` in it's `on:` section, it cannot call another workflow, as the depth limit is 1.
- **Dependent or Chained workflow pattern**: The [workflow_run](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onworkflow_runbranchesbranches-ignore) capability essentially a "defined prerequisites" mechanism. In this case, the workflow being called explicitly describes which workflows can trigger it. The `workflow_run` in the `on:` section of a workflow define the workflow names and conditions (branch patterns and event types) which will trigger it. This pattern seems useful when the need is creation of explicity workflow dependencies. The maximum number of workflows in a chain is 4 (in other words, a [maximum of 3](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_run) levels below the initial workflow).
- **Reusable steps pattern**: The [composite action](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action) capability essentially provides an abstraction mechanism at the step level, as it essentially defines a collection of steps as a reusable unit.This has similarities to the _Reusable workflow pattern_ above in that it seems useful for creation abstractions, just at a different level.
- A reusable workflow can't be combined with a matrix strategy.
- The workflow level `env` cannot be used inside the `with:` when calling a reusable workflow.

## Workflow and Actions Decisions

- Separated CloudFormation "package" and "deploy" activities into separate jobs. While this creates some duplication (i.e. - "checkout" and "configure aws credentials" steps), it also enables failed job re-run functionality. For example, a failed deployment could be re-run without requiring the package step to also be re-run.

## Standardized Structure

### Folders

- Application code (e.g. - Lambdas): `/src/app`
- CICD code: `/.github`
- Infrastructure code: `/src/infra`
- Prerequisites: `/src/prereqs`

### CloudFormation files

- CloudFormation templates: `template.yml`
- CloudFormation template parameters: `params.json`
- CloudFormation stack config (cli input for stack create and update commands): `stack-config.yml`
- CloudFormation stackset config (cli input for stackset create and update commands): `stackset-config.yml`
- CloudFormation stack instances config (cli input for stack instances create and update commands): `stack-instances.yml`

## CICD Inventory

The current CICD configuration works as follows:

- A component-specific workflow runs on push and pull request events if the component has changed. CI operations (linting, validation) are performed for both push and pull request events. CD operations (package, deploy) are performed only for push events to main and after CI operations have completed.
- A comprehensive workflow runs on push events for all changes not related to documentation. CI operations are performed for all components.
- All other sample workflows are configured for manual execution only.

### Top Level Workflows

Top level workflows are identified by naming convention, specifically those files in the `.github/workflows` folder which start with `ci` or `cd`.

#### All components CICD

These "comprehensive" workflows illustrate the approach of performing CI and CD operations on all components in the repository.

- `ci-all.yml`: Continuous integration of all components in the repository, using the reusable workflow `qa-cfn.yml`. This comprehensive workflow uses a matrix strategy to perform CI operations for all components as quickly as possible.
- `cd-all.yml`: Orchestrated deployment of all components in the repository, using the reusable workflow `deploy-cfn.yml`. This comprehensive workflow accounts for all dependencies between components.

#### Grouped CICD

These "grouped" workflows illustrate the approach of grouping components with both "hub" and "spoke" parts into a single workflow, which orchestrates CD operations based on the dependency between the "hub" and the "spoke".

- `cd-component1.yml`: Workflow triggered only on changes to `component1-hub` or `component1-spoke`, performing CD operations on push events. The "hub" component is deployed first, followed by the "spoke" component.

#### Targeted CICD

These "targeted" workflows seem to be the simplest approach to implementing component-specific CICD. This design minimizes duplication while also implementing CI and CD operations in the most common way (CI in PR, CI + CD on merge).

- `cicd-component1-hub.yml`: Workflow triggered only on changes to `component1-hub`, performing CI operations on push and pull request events, and CI + CD operations on push events.
- `cicd-component1-spoke.yml`: Workflow triggered only on changes to `component1-spoke`, performing CI operations on push and pull request events, and CI + CD operations on push events.
- `cicd-component2.yml`: Workflow triggered only on changes to `component2`, performing CI operations on push and pull request events, and CI + CD operations on push events.

#### Separate CICD

- `ci-component1-hub.yml`: Workflow triggered only on changes to `component1-hub`, performing CI operations on push and pull request events.
- `ci-component1-spoke.yml`: Workflow triggered only on changes to `component1-spoke`, performing CI operations on push and pull request events.
- `ci-component2.yml`: Workflow triggered only on changes to `component2`, performing CI operations on push and pull request events.
- `cd-component1-hub.yml`: Workflow triggered only on changes to `component1-hub`, performing CD operations on push events.
- `cd-component1-spoke.yml`: Workflow triggered only on changes to `component1-spoke`, performing CD operations on push events.
- `cd-component2.yml`: Workflow triggered only on changes to `component2`, performing CD operations on push events.

### Reusable Workflows

Reusable workflows are identified by naming convention, specifically those files in the `.github/workflows` folder which do _NOT_ start with `ci` or `cd`.

- `deploy-cfn.yml`: Workflow which packages the specified CloudFormation template, including upload to S3, then deployed the template to the AWS account configured for this repository (see the [prerequisites](#prerequisites)).
- `qa-cfn.yml`: Workflow which performs quality checks on the specified CloudFormation template, specifically linting using `cfn-lint` and validation using the AWS CLI.

### Composite Actions

- `cfn-deploy`: Performs a deploy for either a CloudFormation stack or stackset, depending on inputs provided.
- `cfn-lint`: Lints the specified CloudFormation template using the `cfn-lint` utility.
- `cfn-package`: Packages the specified CloudFormation template and uploads it to S3.
- `cfn-validate`: Validates the specified CloudFormation template using the AWS CLI.

### Reusable Scripts

- `deploy-stack.sh`: Bash script which deploys a CloudFormation stack from an S3 location. Checks if the stack exists and then performs a create or an update. The script waits until the create or update operation completes.
- `deploy-stackset-sh`: Bash script which deploys a CloudFormation stackset from an S3 location. Checks if the stackset exists and then performs a create or an update. After the create or update, a "create instances" is performed to add or update stack instances as defined in the instances configuration file. The script waits until the create or update operation completes.

## References

- [Parallel and dependent job processing](https://lannonbr.com/blog/github-actions-jobs)
- [Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Creating Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)

## Tips and Tricks

- Use the following command to configure a script with executable permissions for GitHub Actions: `git update-index --chmod=+x myscript.sh`
