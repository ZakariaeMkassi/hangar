#!/bin/bash
################################ Description ############################################
# This script is used to build and push an image to a container registry
################################# Arguments #############################################
# -f : Path to the dockerfile
# -c : The context of the build (in our case, the repository cloned and the build application are not in the same directory, we need to execute the docker build knowing that)
# -u : Username to connect to the registry
# -p : Password to connect to the registry
# -r : Registry used to store the image
# -i : Name of the image (containing the name of the registry and the path to the image)
# -b : Name of the branch from where the version is coming
# -q : Version Tag
#########################################################################################
set -e

while getopts q: flag
do
    case "${flag}" in
        q) tag=${OPTARG};;
        *) echo "flag ${flag} not specified"
    esac
done

# we get what is located after the last '/' in the branch name, so it removes /ref/head or /ref/head/<folder> if your branch is named correctly
branch_short=$(echo "$branch" | awk -F '/' '{ print $NF }')

# We change the name of the tag depending if it is a release or another branch
echo "$branch" | grep release && tag_completed="${tag}"
echo "$branch" | grep release || tag_completed="${tag}_${branch_short}"

# We build the image
echo "docker build -f $dockerFile -t $imageName:$tag_completed $context"
docker build -f "$dockerFile" -t "$imageName":"$tag_completed" "$context"

# We connect to the registry
if test -z "$aws_access_key"
then
    echo "docker login -u=**** -p=**** $registry"
    docker login -u="$username" -p="$password" "$registry"
else
    aws configure set aws_access_key_id "$aws_access_key"
    aws configure set aws_secret_access_key "$aws_secret_access_key"
    echo "aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $registry"
    aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$registry"
fi

# We push the image previously built
echo "docker push $imageName:$tag_completed"
docker push "$imageName":"$tag_completed"

# If this is a release we push it a second time with "latest" tag
if echo "$branch" | grep release
then
    echo "Also pushing the image as 'latest' if this is a release"
    docker tag "$imageName:$tag_completed" "$imageName:latest"
    echo "docker push $imageName:latest"
    docker push "$imageName":latest
fi
