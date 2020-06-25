PROJECT_ID=$1

gcloud projects describe $PROJECT_ID
gcloud projects describe $PROJECT_ID --format 'value(projectNumber)'

gcloud sql instances list --project $PROJECT_ID

gcloud run services list --project $PROJECT_ID

gcloud iam service-accounts list --project $PROJECT_ID

gcloud secrets list --project $PROJECT_ID

gcloud projects get-iam-policy $PROJECT_ID

gcloud secrets versions access latest --secret django_settings --project $PROJECT_ID
