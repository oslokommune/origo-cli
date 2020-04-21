#!/bin/sh
# Create dataset and pipeline to process any data pushed to the dataset

# This is the first edition of the script, if it fails: please review the setup and
# re-run the script -->
#   If a dataset_id is created and you have to re-run the script because creating the
#   version fails: set dataset_id to the ID you get from the output of this script, then comment out the
#   "Dataset" block further below

# Requires: jq
echo "Update json files in this directory before running"
echo "### Uncomment this line to run ###\n" && exit 1

echo "Creating a dataset, edition, pipeline and uploading a file to test"
echo "Please wait....."

######### Input files #########
# These files MUST be updated:
dataset_file="dataset.json"
dataset_version_edition_file="dataset-version-edition.json"
# No need to update the following files:
dataset_version_file="dataset-version.json"
dataset_upload_file="hello_world.csv"
pipeline_instance_file="pipeline.json"
pipeline_input_file="pipeline-input.json"

######### Basic check to see if user have updated data in files #########
dataset_data=`cat $dataset_file`
if [[ $dataset_data =~ "boilerplate" || $dataset_data =~ "my.address@example.org" || $dataset_data =~ "Publisher Name" ]]
then
   echo "Error: $dataset_file has not been updated correctly - please change the data to represent the dataset you want to create and the organization creating it!"
   exit
fi
version_data=`cat $dataset_version_edition_file`
if [[ $version_data =~ "Boilerplate" || $version_data =~ "2020-00-00" ]]
then
   echo "Error: $dataset_version_edition_file has not been updated correctly - please change the data to represent the edition you want to create"
   exit
fi

######### Dataset #########
dataset=`origo datasets create --file=$dataset_file --format=json`
dataset_id=`echo "$dataset" | jq  -r '.Id'`
if [[ $dataset_id == null ]]; then
    echo "Could not create dataset"
    echo $dataset | jq
    exit
fi
echo "Created Dataset:: $dataset_id"

######### Dataset Version #########
version=`origo datasets create-version $dataset_id --file=$dataset_version_file --format=json`
version_id=`echo "$version" | jq  -r '.version'`
if [[ $version_id == null ]]; then
    echo "Could not create version"
    echo $version | jq
    exit
fi
echo "Created version: $version_id"

######### Dataset Edition #########
# Format for dataset-version-edition.json fields:
#   DATE_SHORT=`date +%Y-%m-%d`
#   DATE_EDITION=`date +%Y-%m-%dT%H:%M:%S+02:00`
edition=`origo datasets create-edition $dataset_id $version_id --file=$dataset_version_edition_file --format=json`
edition_id=`echo "$edition" | jq  -r '.Id'`
if [[ $edition_id == null ]]; then
    echo "Could not create edition"
    echo $edition | jq
    exit
fi
edition_id=`echo $edition_id | cut -d "/" -f 3`
echo "Created edition: $edition_id"

######### Pipeline instance #########
cat $pipeline_instance_file | sed "s/ID/$dataset_id/" | sed "s/VERSION/$version_id/" > generated_pipeline.json
pipeline=`origo pipelines instances create generated_pipeline.json --format=json`
error=`echo $pipeline | jq -r '.error'`
if [[ "$error" =~ ^[1]+$ ]]; then
  echo "Could not create instance"
  echo $pipeline | jq
  exit
fi
pipeline_id=`echo $pipeline | jq -r '.id'`
echo "Created pipeline instance $pipeline_id for dataset: $dataset_id "

######### Pipeline input #########
cat $pipeline_input_file | sed "s/ID/$dataset_id/" | sed "s/VERSION/$version_id/" | sed "s/PIPELINEINSTANCE/$pipeline_id/"  > generated_pipeline_input.json
input=`origo pipelines inputs create generated_pipeline_input.json --format=json`
error=`echo $input | jq -r '.error'`
if [[ "$error" =~ ^[1]+$ ]]; then
  echo "Could not create inputs"
  echo $input | jq
  exit
fi
echo "Created input for $dataset_id"

######### Copy file to dataset #########
upload=`origo datasets cp $dataset_upload_file ds:$dataset_id $version_id $edition_id --format=json`
error=`echo $upload | jq -r '.error'`
if [[ "$error" =~ ^[1]+$ ]]; then
  echo "Could not upload file"
  echo $upload | jq
  exit
fi
status_id=`echo "$upload" | jq  -r '.statusid'`
echo "Uploaded test file to dataset $dataset_id, status id for upload is $status_id"

######### Check status for the newly uploaded file #########
uploaded=false
echo "Checking status for uploaded file"
while ! $uploaded; do
  echo "\Checking upload status....."
  upload_status=`origo status $status_id --format=json`
  uploaded=`echo $upload_status | jq -r '.done'`
done
echo "Uploaded file is processed and ready to be consumed"