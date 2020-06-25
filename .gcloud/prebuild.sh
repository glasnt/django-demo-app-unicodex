#!/bin/bash
shopt -s expand_aliases

function quiet {
    $* > /dev/null
}

stepdo() { 
    echo "→ ${1}..."
}

# this will only capture the most recent return code, sadly.
stepdone(){
    statuscode=$?
    msg="... done"
    if [ $statuscode -ne 0 ]; then msg="❌  done, but non-zero return code ($statuscode)"; fi
    echo $msg
    echo " "
}

echo "🚀 Deploying $K_SERVICE to $GOOGLE_CLOUD_PROJECT in $GOOGLE_CLOUD_REGION"
export PROJECT_ID=$GOOGLE_CLOUD_PROJECT
gcloud config set project $PROJECT_ID
gcloud config set run/platform managed
export REGION=$GOOGLE_CLOUD_REGION
gcloud config set run/region $REGION
export SERVICE_NAME=$K_SERVICE
export INSTANCE_NAME=psql

stepdo "Enabling Google API services"
gcloud services enable \
  run.googleapis.com \
  iam.googleapis.com \
  compute.googleapis.com \
  cloudbuild.googleapis.com \
  cloudkms.googleapis.com \
  cloudresourcemanager.googleapis.com \
  secretmanager.googleapis.com
stepdone

stepdo "Creating dedicated service account for $SERVICE_NAME"
gcloud iam service-accounts create $SERVICE_NAME \
  --display-name "$SERVICE_NAME service account"
stepdone

export CLOUDRUN_SA=${SERVICE_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
export PROJECTNUM=$(gcloud projects describe ${PROJECT_ID} --format 'value(projectNumber)')
export CLOUDBUILD_SA=${PROJECTNUM}@cloudbuild.gserviceaccount.com

stepdo "Grant IAM permissions to service accounts"
for role in cloudsql.client run.admin; do
  quiet gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:$CLOUDRUN_SA \
    --role roles/${role}
  quiet gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${CLOUDBUILD_SA} \
    --role roles/${role}
done
quiet gcloud iam service-accounts add-iam-policy-binding ${CLOUDRUN_SA} \
  --member "serviceAccount:${CLOUDBUILD_SA}" \
  --role "roles/iam.serviceAccountUser"
stepdone

stepdo "Create Storage bucket"
export GS_BUCKET_NAME=${PROJECT_ID}-media
gsutil mb -l ${REGION} gs://${GS_BUCKET_NAME}
gsutil iam ch \
  serviceAccount:${CLOUDRUN_SA}:roles/storage.objectAdmin \
  gs://${GS_BUCKET_NAME} 
stepdone

stepdo "Creating Django settings secret, and allowing service access"
echo GS_BUCKET_NAME=\"${GS_BUCKET_NAME}\" >> .env
echo SECRET_KEY=\"$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)\" >> .env
gcloud secrets create django_settings --replication-policy automatic
gcloud secrets versions add django_settings --data-file .env
quiet gcloud secrets add-iam-policy-binding django_settings \
  --member serviceAccount:$CLOUDRUN_SA \
  --role roles/secretmanager.secretAccessor
quiet gcloud secrets add-iam-policy-binding django_settings \
  --member serviceAccount:$CLOUDBUILD_SA \
  --role roles/secretmanager.secretAccessor
stepdone

stepdo "Creating Django admin user secrets, and allowing limited access"
export SUPERUSER="admin"
export SUPERPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 30 | head -n 1)
for SECRET in SUPERUSER SUPERPASS; do
  gcloud secrets create $SECRET --replication-policy automatic
  echo -n "${!SECRET}" | gcloud secrets versions add $SECRET --data-file=-
  quiet gcloud secrets add-iam-policy-binding $SECRET \
    --member serviceAccount:$CLOUDBUILD_SA \
    --role roles/secretmanager.secretAccessor
done 
stepdone

echo "Pre-build provisioning complete ✨"
