# Deployment Guide - Guidance to create Sustainability Sourcing Assistant for SAP on AWS
This guide shows how to enhance business efficiency and user experience through real-time data integration from SAP and non-SAP sources, automated task management, comprehensive data summaries, and intuitive natural language interactions.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Code Deploymet](#code-deploymet-to-build-bedrock-lambda-and-knowlede-base)
- [Test Conversation](#test-conversation)
- [Configure AWS Amplify Web UI for Your Agent](#configure-aws-amplify-ui-to-connect-to-amazon-bedrock)
- [Conclusion](#conclusion)
- [Clean-up](#clean-up)

## Overview
SAP Business users are seeking secure and reliable generative AI solutions to support their modernization strategies. Amazon Bedrock, a fully managed service, offers access to various foundation models from leading AI companies and provides comprehensive capabilities for building generative AI applications while maintaining security and compliance standards.

In the procurement space, generative AI is transforming sustainable sourcing practices. Organizations face challenges in managing quotations, accessing sustainability data, and integrating information from multiple sources. The Sustainability Sourcing Assistant, powered by Amazon Bedrock, demonstrates how generative AI can integrate with SAP data to address these challenges.

Key procurement pain points include time-consuming quotation review processes, the need to access multiple external data sources for sustainability information, and difficulties in obtaining comprehensive sustainability data outside SAP. By leveraging generative AI solutions, procurement teams can make more informed decisions, enhance sustainability practices, and significantly reduce the time spent on quotation management. This example showcases how generative AI can be applied to improve efficiency and strategic decision-making in supply chain management.


<p align="center">
  <img src="../Architecture/arch01.png" width="90%" height="90%"><br>
  <span style="display: block; text-align: center;"><em>Figure 1: Architecture topology of the solution</em></span>
</p>

The use case utilizes a range of AWS services and SAP technologies.  The numbers below are references to the diagram “High Level steps & architecture diagram”.
1.	Data Extraction: Amazon AppFlow connects to SAP OData Connector for near real-time data extraction.
2.	Data Storage: Amazon S3 stores extracted data in JSON format. The data is crawled using Glue crawler.
3.	User Interface: A chatbot assistant using AWS Amplify receives natural language inputs from users. Authentication happens through Amazon cognito.
4.	Processing: Bedrock Agent interprets user input, leveraging its chat history and underlying Foundation Model.
5.	Action Orchestration: Bedrock Agent is configured with Action Groups to manage processing steps.
6.	Data Querying: Lambda functions translate natural language to SQL queries for Athena database.
7.	SAP Integration: AWS Lambda invokes SAP API to create Purchase Orders in SAP.
8.	AWS Secrets Manager used to store and retrieve credentials for SAP
9.  Knowledge Enhancement: Amazon Bedrock's Knowledge Base provides managed RAG for additional context (sustainability information).
10.	Data Preparation: S3 bucket data is synced and transformed into embeddings for machine learning use.
11.	Response Generation: The agent curates a final response, delivered via an AWS Amplify (extendable to other UIs).

## Cost
*We recommend creating a [Budget](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html) through AWS [Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/) to help manage costs. Prices are subject to change. For full details, refer to the pricing webpage for each AWS service used in this Guidance.*


AWS Monthly Costs
Total estimated cost: ~$900/month for 30,000 purchase orders

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| AWS S3 | Standard Storage - 500GB | $11.50 |
| AWS Lambda | 30,000 POs × 10 calls each | $3.19 |
| AWS AppFlow | 4 flows every 2 minutes | $87.60 |
| Amazon Bedrock (Titan Embedding) | 500 docs with 10,000 tokens | $12.00 |
| Amazon Bedrock (Claude v3-Sonnet) | 15 RPM - 100 input/250 output tokens | $875.00 |
| AWS Amplify | 10 build minutes per hour, 1 GB data, 500 SSR, 500ms request duration, WAF | $98.42 |

## Cost Optimization Recommendations
- Monitor costs closely during POC phase
- Scale services based on specific use case requirements
- Adjust frequency of data flows based on business needs
- Optimize token usage in AI models
- Actual costs may vary based on usage patterns and regional pricing
- Consider reserved instances or savings plans for long-term deployments
- Evaluate cost-benefit ratio against manual processing alternatives

## Prerequisites

## SAP configuration

1. Create the OData Services in SAP that will be used as data providers through ODP.
This solution guidance utilises SAP Standard Delta Enabled CDS views. These views need to be exposed as OData services in transaction SEGW. You can follow this [blog](https://community.sap.com/t5/technology-blog-posts-by-members/exposing-sap-bw-extractors-via-odp-as-an-odata-service/ba-p/13473362), from step 3 onwards, selecting ABAP Core Data Services instead of DataSources/Extractors (see screenshot below).

<p align="center">
  <img src="../imgs/Odata1.png" width="90%" height="90%"><br>
  <span style="display: block; text-align: center;"><em>Figure 2: Create Odata service in SAP</em></span>
</p>

2. SAP CDS Views and ODP Configuration
Create the following, as per the previous blog instructions using the code for the CDS views provided in this section.

| Short Description | CDS View Name | ODP Name | Odata Service name |
|------------------|---------------|----------| ----------|
| RFQ Header | ZRFQ |  ZRFQV$F | ZCDS_RFQ |
| RFQ Item | ZRFQITEM | ZRFQITEMV$F | ZCDS_RFQ_ITEM |
| Supplier Quote Header | ZSUPPLIERQUOTE | ZSUPPLIERQUOTEV$F | ZCDS_SUPPLIER_QUOTE |
| Supplier Quote Item | ZSUPPLIERQUOTEITEM | ZSUPPLQUOTEITEMV$F | ZCDS_SUPPLIER_QUOTE_ITEM |

Example code which can be used to create the CDS views can be found below for ZRFQ, ZRFQITEM, ZSUPPLIERQUOTE & ZSUPPLIERQUOTEITEM.

[ZRFQV](../sap-cds-views/ZRFQV)
[ZRFQITEMV](../sap-cds-views/ZRFQITEMV)
[ZSUPPLIERQUOTEV](../sap-cds-views/ZSUPPLIERQUOTEV)
[ZSUPPLQUOTEITEMV](../sap-cds-views/ZSUPPLQUOTEITEMV)

# Amazon S3 Bucket Setup Instructions

## 1. Create S3 Bucket

Create a new S3 bucket with a name of your choosing.	

First we need to create an Amazon S3 bucket which will be used to store the Request for Quotation (RFQ) and Supplier quotation item detail.  Amazon Appflow will use this bucket to extract the data from SAP. Details for creating an Amazon S3 bucket can be found [here](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html)

Example: rfq-12345678910 (example, replace the number with your account number)

### Create the SAP Connection in Amazon AppFlow
Next we need to define the SAP system in Amazon AppFlow as a “Connection”

1. Go to Amazon AppFlow Service in the AWS console and go to Connections:
<p align="center">
  <img src="../imgs/appflow1.png" width="90%" height="90%"><br>
</p>

<p align="center">
  <img src="../imgs/appflow2.png" width="90%" height="90%"><br>
</p>

2. Click on the drop-down to choose a Connector type, search for SAP and choose SAP OData.

<p align="center">
  <img src="../imgs/appflow3.png" width="90%" height="90%"><br>
</p>

Afterwards click on Create Connection

<p align="center">
  <img src="../imgs/appflow4.png" width="60%" height="60%"><br>
</p>

3. In the following screen, the connection parameters need to be defined:

<p align="center">
  <img src="../imgs/appflow5.png" width="60%" height="60%"><br>
</p>

Connection name is the name of the connection, we can use anything. For example sap--system

Select authentication method selects between Basic Auth or OAUTH2. We select Basic Auth for username/password

Bypass SAP single sign-on (SSO) needs to be “Yes” if the system has SSO login enabled and we want to connect with a technical user.

User name and Password are the fields that define the username and password of the technical user that has the required authorizations to read from the OData Services that we previously defined.

Application host URL is the FQDN HTTPS URL of the SAP System. This URL needs to be publicly available, otherwise we need to use PrivateLink that requires additional configuration. Example: https://sap--workshop.awsforsap.sap.dummydomain.com

Application service path is the path to the OData Catalog Service which is usually: /sap/opu/odata/iwfnd/catalogservice;v=2

Port number is the HTTPS port of the SAP System, for example 443

Client number is the productive client number of the SAP system, for example 100

Logon language is the logon language of the SAP system, for example en (english)

PrivateLink can be left Disabled if there is a public accessible HTTPS URL for the SAP System.

If this is not the case, you need to enable it and also follow the instructions in the following [blog for some extra configurations:](https://aws.amazon.com/blogs/awsforsap/share-sap-odata-services-securely-through-aws-privatelink-and-the-amazon-appflow-sap-connector)

Data encryption can be left on default as the encryption is already done by an AWS managed key

An example configuration with publicly accessible HTTPS URL can look like this (replace <sid> with your SID and the Application host URL with your own)

Clicking on Connect creates the Connection.

## Configure Appflow flows to Amazon S3

1. Amazon Appflow > Flows > Create Flow
<p align="center">
  <img src="../imgs/flow1.png" width="90%" height="90%"><br>
</p>

2. Enter name of Flow, this example is for RFQ HEADER
<p align="center">
  <img src="../imgs/flow2.png" width="90%" height="90%"><br>
</p>

3. Select Source details, using the OData connection you created earlier (in this example we are using the name "sapconnection").
<p align="center">
  <img src="../imgs/flow3.png" width="90%" height="90%"><br>
</p>

Enter thr SAP OData object, and subobject which we created as part of the SAP prerequisites earlier.
Example SAP OData object = ZCDS_RFQ_SRV
SAP Odata subobject FactsOfZRFQV

4. Select the Destination details for the flow.  use the bucket name you created earlier prefix rfq-xxx
<p align="center">
  <img src="../imgs/flow4.png" width="90%" height="90%"><br>
</p>
5. Change flow trigger to Run flow on Schedule.  In this example we will run on every 5 minutes.
<p align="center">
  <img src="../imgs/flow5.png" width="90%" height="90%"><br>
</p>

6. Map data fields

Select source field name, and Map all fields directly.  

<p align="center">
  <img src="../imgs/flow6.png" width="90%" height="90%"><br>
</p>


You should then end up with the following. Notice the Field Mappings at the bottom.
<p align="center">
  <img src="../imgs/flow7.png" width="90%" height="90%"><br>
</p>

Click Next

In the Add Filters screen, select next as we wont be adding any filters in this example
<p align="center">
  <img src="../imgs/flow8.png" width="90%" height="90%"><br>
</p>

In the next screen you will be presented with a summary.  Click on Create flow button on the bottom right of the screen.

Click on Run Flow
<p align="center">
  <img src="../imgs/flow9.png" width="90%" height="90%"><br>
</p>

Repeat the above for the remaining flows.

| Flow Name | SAP OData Object | SAP OData Subobject | Description |
|-----------|-----------------|-------------------|-------------|
| RFQ_ITEMS | ZCDS_RFQ_ITEM_SRV | FactsOfZRFQITEMV | Request for Quotation Items data service |
| SUPPLIER_QUOTATION_HEADER | ZCDS_SUPPLIER_QUOTE_SRV | FactsOfZSUPPLIERQUOTEV | Supplier Quotation Header information service |
| SUPPLIER_QUOTATION_ITEMS | ZCDS_SUPPLIER_QUOTE_ITEM_SRV | FactsOfZSUPPLQUOTEITEMV | Supplier Quotation Line Items data service |



## Create database and Glue Crawler in Amazon Glue 

1.	Create AWS Glue Database and Glue Crawler.

Go to [AWS Glue](https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html), and click on Crawlers in the left-hand panel. Click Create crawler.  Follow the instructions as per the online documentation to [create a crawler](https://docs.aws.amazon.com/glue/latest/dg/tutorial-add-crawler.html) and “run on demand”. Do this for each of the folders in the S3 bucket you created earlier.  

**Note you have the option to create a database when walking through the steps to create the crawler.  In our example we have created a database called “athena_db”**

Create crawler.
<p align="center">
  <img src="../imgs/crawl1.png" width="90%" height="90%"><br>
</p>

Set name and description.
<p align="center">
  <img src="../imgs/crawl2.png" width="90%" height="90%"><br>
</p>

click Add data source
<p align="center">
  <img src="../imgs/crawl3.png" width="90%" height="90%"><br>
</p>

Select the Amazon S3 bucket which we intend to crawl. This contains the appflow data we setup earlier.
<p align="center">
  <img src="../imgs/crawl4a.png" width="50%" height="60%"><br>
</p>

Next.
<p align="center">
  <img src="../imgs/crawl5.png" width="90%" height="90%"><br>
</p>

Select create new IAM role.
<p align="center">
  <img src="../imgs/crawl6.png" width="90%" height="90%"><br>
</p>

Give the postfix of whatever makes sense, in this example we have used the postfix SAP.
<p align="center">
  <img src="../imgs/crawl7.png" width="90%" height="90%"><br>
</p>

Click Add database.
<p align="center">
  <img src="../imgs/crawl8.png" width="90%" height="90%"><br>
</p>

Name the database to athena_db, which is the name of the database used in the Lambda function.
<p align="center">
  <img src="../imgs/crawl9.png" width="90%" height="90%"><br>
</p>

Now back to the Crawler configuration and selcet the databse we just created.  In our case athena_db.

<p align="center">
  <img src="../imgs/crawl10.png" width="90%" height="90%"><br>
</p>

In the summary screen select create crawler.

<p align="center">
  <img src="../imgs/crawl11.png" width="90%" height="90%"><br>
</p>

In the next screen, click run crawler.

<p align="center">
  <img src="../imgs/crawl12.png" width="90%" height="90%"><br>
</p>

The crawler should start running, and you will see the tables it has created once it's completed.  Here you can see its found 4 tables in the Amazon s3 bucket.

<p align="center">
  <img src="../imgs/crawl13.png" width="90%" height="90%"><br>
</p>

If you click on the tables you can see whats been created.

<p align="center">
  <img src="../imgs/crawl14.png" width="90%" height="90%"><br>
</p>

Next we will validate we can access the data in Amazon Athena.  This is so we can query in Amazon Athena, and use within Amazon Bedrock as part of the use case.

## Validate with Amazon Athena

1.	Query Amazon Athena Database to validate
Go to Athena, select Data Source “AwsDataCatalog” on the left-hand pane, select database “athena_db”, or the name you used earlier. 

<p align="center">
  <img src="../imgs/ath1.png" width="30%" height="60%"><br>
</p>


Run a simple query to confirm you can query the data.
```
SELECT * 
FROM rfq_header
ORDER BY creationdate
```

> NOTE: If you receive the message "Before you run your first query, you need to setup a query result location in Amazon S3":

<p align="center">
  <img src="../imgs/s3warning.png" width="60%" height="40%"><br>
</p>

> Click the "Settings" tab in the top right corner of Athena

> In the "Query result location" field, enter an S3 path:

> Format: s3://your-bucket-name/folder/

> Example: s3://your-name-athena-results/query-results/

> Click "Save"

> Return to your query and try running it again

> Note: If you don't have an S3 bucket already, click the "Browse S3" button next to the location field to create one.

<p align="center">
  <img src="../imgs/ath2.png" width="90%" height="90%"><br>
</p>

You should now see data returned directly from the bucket.  In this example we are querying the table rfq_header, in database athena_db. This database was created when we ran the crawler earlier.


## Prepare Frontend Code Component
The chat interface for this solution is built using React and hosted on AWS Amplify.

**Note:** This deployment.zip would be requested to be copied to ***frontend*** folder in our repository to deploy it as application in AWS Amplify

1. Clone repository to your local machine:

```bash
git clone https://github.com/aws-samples/sample-cognito-integrated-bedrock-agents-chat-ui.git
```

2. Change directory to the folder:
```bash
cd sample-cognito-integrated-bedrock-agents-chat-ui
```

3. Install dependencies:
```bash
npm install
```

**Success Criteria**: All dependencies are installed without errors.

4. Build the application:

```bash
npm run build
```

5. Package the dist folder contents:

```bash
cd dist
zip -r ../deployment.zip ./*
cd ..
```

## Enable Models in Bedrock
Before proceeding with deployment, verify that you have access to the Amazon Bedrock console and can request access to Amazon Bedrock foundation models. Instructions for requesting access are available in the provided [link](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html).  You will also require an S/4HANA system, which can run in RISE for SAP on AWS, AWS Native, or On-Premise.

The deployment uses the below two models, ensure you have access to both of the models
  1. Titan Text Embeddings V2 
  2. Claude 3 Sonnet


## Code Deployment to build bedrock, lambda and Knowledge Base
By default, [AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html) uses a temporary session that it generates from your user credentials for stack operations. If you specify a service role, CloudFormation will instead use that role's credentials.

To deploy this solution, your IAM user/role or service role must have permissions to deploy the resources specified in the CloudFormation template. For more details on [AWS Identity and Access Management](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html) (IAM) with CloudFormation, please refer to the [AWS CloudFormation User Guide](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-template.html).

You must also have [AWS Command Line Interface](https://aws.amazon.com/cli/) (CLI) installed. For instructions on installing AWS CLI, please see [Installing, updating, and uninstalling the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

### 1. Clone [_amazon-bedrock-sap-sustainability-assistant_](git@ssh.gitlab.aws.dev:mahasrid/SAP-GenAI-Sustainability-Assistant.git) Repository

Create a local copy of the **amazon-bedrock-sap-sustainability-assistant** repository using _git clone_:

```sh
git clone git@ssh.gitlab.aws.dev:mahasrid/SAP-GenAI-Sustainability-Assistant.git
```

#### Optional - Run Security Scan on the AWS CloudFormation Templates
To run a security scan on the AWS CloudFormation templates using [`cfn_nag`](https://github.com/stelligent/cfn_nag) (recommended), you have to install `cfn_nag`:

```sh
brew install ruby brew-gem
brew gem install cfn-nag
```

To initiate the security scan, run the following command:
```sh
# git clone git@ssh.gitlab.aws.dev:mahasrid/SAP-GenAI-Sustainability-Assistant.git
# cd amazon-bedrock-sap-sustainability-assistant
cfn_nag_scan --input-path cfn/sap-assistant-resources-01.yml
cfn_nag_scan --input-path cfn/sap-assistant-resources-02.yml
```
---

### 2. Copy deployment.zip genereated as part of Prerequisites
Copy deployment.zip to frontend folder

```sh
cp ../sample-cognito-integrated-bedrock-agents-chat-ui/deployment.zip frontend/
```
---

### 3. Deploy CloudFormation Stack to Emulate SAP assistant
To emulate the creation of resources utilized by the agent, this solution uses the [create-sap-assistant.sh](../shell/create-sap-assistant.sh) shell script to automate provisioning of the parameterized CloudFormation template, [sap-assistant-resources-01.yml](../cfn/sap-assistant-resources-01.yml)

CloudFormation prepopulates stack parameters with the default values provided in the template. To provide alternative input values, you can specify parameters as environment variables that are referenced in the `ParameterKey=<ParameterKey>,ParameterValue=<Value>` pairs in the _create-customer-resources.sh_ shell script's `aws cloudformation create-stack` command. 

a. Before you run the shell script, navigate to the directory where you cloned the _amazon-bedrock-sap-sustainability-assistant_ repository and modify the shell script permissions to executable:

If not already cloned, clone the remote repository (https://github.com/aws-samples/amazon-bedrock-sap-sustainability-assistant) and change working directory to shell folder:

The Lambda layer contains third-party Python packages (requests, opensearch-py) that aren't included in the standard AWS Lambda runtime, so you must build and package these dependencies locally before deployment to ensure the Lambda functions can make HTTP calls to SAP systems and interact with OpenSearch.
```sh
Build the layer:
cd agent/lambda
chmod +x build-layer.sh
./build-layer.sh
cd ../..

set execute permission on create script, so we are ready for deployment:

cd shell/
chmod u+x create-sap-assistant.sh
chmod u+x delete-sap-assistant.sh
```
b. Set your CloudFormation stack name(STACK_NAME), the stack deployment AWS region (AWS_REGION), Securitygroup id (SECURITY_GROUP_ID) this the security group id of the AWS EC2 instance that runs your SAP environment and two private subnets (PRIV_SUBNET_ID01 and PRIV_SUBNET_ID01) the subnets where your SAP environment is running. 
```sh
export STACK_NAME=<YOUR-STACK-NAME> # Stack name must be lower case for S3 bucket naming convention
export AWS_REGION=<YOUR-STACK-REGION> # Stack deployment region
export SECURITY_GROUP_ID=<YOUR-SECURITY-GROUP-ID> # Security group of AWS EC2 instance that runs SAP environment
export PRIV_SUBNET_ID01=<YOUR-PRIV-SUBNET-ID-01> # Private subnet that can access SAP environment
export PRIV_SUBNET_ID02=<YOUR-PRIV-SUBNET-ID-02> # Private subnet where SAP environment is running
```
c. Run the [create-sap-assistant.sh](../shell/create-sap-assistant.sh) shell script to deploy the emulated hr resources defined in the [sap-assistant-resources-01.yml](../cfn/sap-assistant-resources-01.yml) CloudFormation template. These are the resources on which the agent and knowledge base will be built:

Run the following commands to deploy the resources:  This will kick off the relevant stack creation in CloudFormation.  Please monitor and wait for completion.
```sh
sh ./create-sap-assistant.sh
```

d. The stack deployment process typically takes 5 to 8 minutes. You can track its progress in the AWS CloudFormation Console.
 
Next, we cover how to launch and validate the Sustainability Quotation assistant.

---


### 4. Knowledge Base Configuration 

Knowledge Bases for Amazon Bedrock leverage Retrieval Augmented Generation (RAG), a technique that harnesses customer data stores to enhance responses generated by foundation models. Knowledge bases allow agents to access existing customer data repositories without extensive administrator overhead. To connect a knowledge base to your data, you specify an S3 bucket as the [data source](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base-ingest.html). By employing knowledge bases, applications gain enriched contextual information, streamlining development through a fully-managed RAG solution. This level of abstraction accelerates time-to-market by minimizing the effort of incorporating your data into agent functionality and it optimizes cost by negating the necessity for continuous model retraining to leverage private data.

 a.  Download sample supplier documents from the S3 bucket `<ACCOUNT-ID>-<YOUR-STACK-NAME>-sap-assistant/agent/knowledge-base-assets/` and upload to the S3 bucket sap-supplierbucket-`<ACCOUNT-ID>`. You may also create few more sample documents for different suppliers and upload for test purpose.

 b. Navigate to the [Amazon Bedrock > Build tools > Knowledge bases](https://console.aws.amazon.com/bedrock/home?/knowledge-bases):

 c. Under **Knowledge Bases**, find the knowledge base that starts with suppliersustainabilityinfo and click on it.

 b. Under **Data source** section, you should see a datasource with the name `SupplierS3DataSource-<YOUR-STACK-NAME>` which is pointing to a S3 bucket `sap-supplierbucket-<ACCOUNT-ID>`.
 
 c. Select the checkbox next to the datasource and click  **Sync** to initiate the data source sync:

 e. Once the sync is completed, you will see another green banner with showing that the sync status being completed.

<p align="center">
  <img src="../imgs/01_kb_data_sync.png" width="90%" height="90%"><br>
  <span style="display: block; text-align: center;"><em>Figure 1: Knowledge Base Data Source Sync</em></span>
</p>

### 5. Secrets Manager Update 

[AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) is used to store the SAP credentials. The action group lambda functions read the SAP environment credentials from the secrets manager secrets.

The deployment creates a secret with the name `sap_credentials`.

Update your SAP environment credentials which can call the ODATA APIs. In our usecase we have used bpinst user credentials.

a. Naviage to [AWS Secrets Manager Console](https://console.aws.amazon.com/secretsmanager/listsecrets?).

b. Locate and select the secret `sap_credentials`.

c. Click on `Retrieve secret value` button to edit the password.
<p align="center">
 <img src="../imgs/secret01.png" width="90%" height="90%"><br>
 <span style="display: block; text-align: center;"><em>Figure 1: Secrets Manager Retrieve Secret Value</em></span>
</p>

d. Click on "Edit" button to enter your SAP environment credentials and click on "Save" button.
<p align="center">
 <img src="../imgs/secret02.png" width="90%" height="90%"><br>
 <span style="display: block; text-align: center;"><em>Figure 2: Secrets Manager Update Password</em></span>
</p>


### 6. Action Group Lambda Update 

[AWS Lambda](https://aws.amazon.com/lambda/) functions are used in Amazon Bedrock Agent action groups to execute the business logic for actions determined by the agent. They receive input events containing relevant metadata and API operation details, process the information, and return responses. This allows for customizable, serverless execution of tasks based on user interactions with the agent.

This deployment creates two AWS Lambda functions:
  1. `<YOUR-STACK-NAME>SAPPOCreateLambda-<YOUR-STACK-NAME>`
  2. `<YOUR-STACK-NAME>SAPAthenaResponseLambda-<YOUR-STACK-NAME>`

These Lambda functions are integral components of the Amazon Bedrock Agent setup, handling specific action groups and their associated business logic.

Update the environment variables for the AWS Lambda functions created by this deployment by following these steps:

   a. Naviage to [AWS Lambda Console](https://console.aws.amazon.com/lambda/home?/functions).
  
   b. Locate and select the function named `<YOUR-STACK-NAME>SAPPOCreateLambda-<YOUR-STACK-NAME>`.
  
   c. In the function's configuration page, click on the "Configuration" tab.
     
   d. In the left sidebar, select "Environment variables".

   e. Click the "Edit" button.

   f. Update the following environment variables:

      SAP_BASE_URL: Enter the appropriate Base URL for your applicaiton
      Example: https://yourssaplogin.com

      S3_BUCKET_NAME: Enter the name of any existing S3 bucket in your account 
      Example:rfq-123456778910

<p align="center">
 <img src="../imgs/02_lmd_env_var01.png" width="90%" height="90%"><br>
 <span style="display: block; text-align: center;"><em>Figure 2: Lambda Environment Variable</em></span>
</p>

   g. Click "Save" to apply the changes.

   h. Repeat steps b-g for the function named `Bedrock-txtsql-action-<YOUR-STACK-NAME>`, to update the evironment variable S3_BUCKET_NAME.
      
     S3_BUCKET_NAME: Enter the name of any existing S3 bucket in your account

<p align="center">
 <img src="../imgs/03_lmd_env_var02.png" width="90%" height="90%"><br>
 <span style="display: block; text-align: center;"><em>Figure 3: Lambda Environment Variable</em></span>
</p>

### 7. Bedrock Agents

Bedrock Agents operate through a build-time execution process, comprising several key components:

* **Foundation Model**: Users select a foundation model that guides the agent in interpreting user inputs, generating responses, and directing subsequent actions during its orchestration process.
* **Instructions**: Users craft detailed instructions that outline the agent's intended functionality. Optional advanced prompts allow customization at each orchestration step, incorporating Lambda functions to parse outputs.
* **(Optional) Action Groups**: Users define actions for the agent, leveraging an OpenAPI schema to define APIs for task execution and Lambda functions to process API inputs and outputs.
* **(Optional) Knowledge Bases**: Users can associate agents with knowledge bases, granting access to additional context for response generation and orchestration steps.

The agent in this sample solution will use an Titan-Text Premier foundation model, a set of instructions, action groups, and one knowledge base. The underlining agent is pre-created through cloudformation, and we just associated the knowledge base to it. Next lets prepare and test the agent.

1. Navigate to the Agents section of the Amazon Bedrock console

2. Select your `SustainablityAgent-<YOUR-STACK-NAME>`created and note your Agent ID and Alias ID:
<p align="center">
  <img src="../imgs/04_agent_alias.png" width="95%" height="95%"><br>
  <span style="display: block; text-align: center;"><em>Figure 4: Agent Selection</em></span>
</p>

❗ _Agent ID and Alias ID will be used as environment variable in the later Configure AWS Amplify web UI for your agent section._

3. Access the test window from any page within the agent's working draft console by selecting Test or the left arrow icon at the top right. In the test window, select an alias and its version that appears in the test window

4. Test your agent using the following sample prompts. At this point ensure you have completed the steps mentioned in the [blog](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html)


❗ Always select Prepare after making changes to apply them before testing the agent.

## Test Conversation
The following test conversation example highlights the agent’s ability to invoke action group APIs with AWS Lambda business logic that queries a customer’s [Amazon Athena](https://aws.amazon.com/athena/) table. The same conversation thread showcases agent and knowledge base integration to take decision based on sustainability information and interact with SAP to create purchase order.

Sample Prompts:
* Please list RFQs

* Were any RFQ’s created today?

* How many quotations are received for RFQ `<REPLACE WITH YOUR SAP RFQ>` and from whom and what is the total cost ?

* Do you have sustainability and other payment term details for these suppliers ?

* which was the least expensive quotation number, including sustainability for RFQ `<REPLACE WITH YOUR SAP RFQ>`?

* Create purchase order using quotation `<REPLACE WITH YOUR SAP QUOTATION>` ?

<p align="center">
  <img src="../imgs/05_agent_test.png" width="95%" height="95%"><br>
  <span style="display: block; text-align: center;"><em>Figure 5: Agent Testing and Validation</em></span>
</p>

## Configure AWS Amplify UI to connect to Amazon Bedrock
1. Navigate to CloudFormation and find stack `<YOUR-STACK-NAME>` For example cf-main-sap-automation-18-05-25-sustain-FrontendStack-CKH9PCUB9XA3

2. View the outputs, which we need for setting up the frontend UI.
<p align="center">
  <img src="../imgs/frotnend01.png" width="95%" height="95%"><br>
  <span style="display: block; text-align: center;"><em>Figure 6: Stack Output</em></span>
</p>

3. Launch the frontend UI using the URL FrontendAppURL from the stack output and enter the configuration details as shown below and press save configuration. The values can be obtained from the stack output section.

<p align="center">
  <img src="../imgs/frotnend02.png" width="95%" height="95%"><br>
  <span style="display: block; text-align: center;"><em>Figure 7: Configure UI</em></span>
</p>

5. Register new user using an email id and password.

<p align="center">
  <img src="../imgs/frotnend03.png" width="50%" height="50%"><br>
  <span style="display: block; text-align: center;"><em>Figure 8: Register new user</em></span>
</p>

You would receive a verification code to complete the registration process.

<p align="center">
  <img src="../imgs/frotnend04.png" width="50%" height="50%"><br>
  <span style="display: block; text-align: center;"><em>Figure 9: Complete registration</em></span>
</p>

6. Now login and test, by asking questions just like we did in the Test section earlier.

Create purchase order test example, replace with your quotation number

<p align="center">
  <img src="../imgs/amp4.png" width="95%" height="95%"><br>
  <span style="display: block; text-align: center;"><em>Figure 11: Chat Frontend UI App</em></span>
</p>

# Conclusion
The solution provides a practical example of how generative AI can be implemented in enterprise environments while maintaining security, reliability, and integration with existing SAP workflows. It's important to note that this is not a turn-key product or service, but rather a demonstration of how various technologies can be combined to address common challenges in procurement. This use case serves as an inspiration for how similar approaches could be adopted and customized for various needs within your organization.  

# Clean up
To avoid charges in your AWS account, please clean up the solution's provisioned resources.

## Delete Emulated SAP Assistant
The [delete-sap-assistant](../shell/delete-sap-assistant.sh) shell script empties and deletes the solution's Amazon S3 bucket and deletes the resources that were originally provisioned from the [sap-assistant-resources-01.yml](../cfn/sap-assistant-resources-01.yml) CloudFormation stack. The following commands use the default stack name. If you customized the stack name, adjust the commands accordingly.

```sh
# cd amazon-bedrock-sap-sustainability-assistant/shell/
# chmod u+x delete-sap-assistant
./delete-sap-assistant
```

The preceding ./delete-sap-assistant shell command runs the following AWS CLI commands to delete the emulated hr resources stack and Amazon S3 bucket:

```sh
export STACK_NAME=$(echo $STACK_NAME | tr '[:upper:]' '[:lower:]')
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ARTIFACT_BUCKET_NAME=$ACCOUNT_ID-$STACK_NAME-sap-assistant

echo "Emptying and Deleting S3 Bucket: $ARTIFACT_BUCKET_NAME"

aws s3 rm s3://${ARTIFACT_BUCKET_NAME} --region ${AWS_REGION} --recursive
aws s3 rb s3://${ARTIFACT_BUCKET_NAME} --region ${AWS_REGION}

echo "Deleting CloudFormation Stack: $STACK_NAME"

aws cloudformation delete-stack --stack-name $STACK_NAME --region ${AWS_REGION} 
aws cloudformation describe-stacks --stack-name $STACK_NAME --region ${AWS_REGION} --query "Stacks[0].StackStatus"
```

---

Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

