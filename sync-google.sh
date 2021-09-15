function gam() { "$HOME/bin/gam/gam" "$@" ; }

export FILEPATH=$(realpath $0)
export PROJECT_DIR=$(dirname $FILEPATH)

if [ -f $PROJECT_DIR/.env ]; then
    . $PROJECT_DIR/.env
fi

mkdir -p $PROJECT_DIR/data
mkdir -p $PROJECT_DIR/log

printf "Extracting user files from database...\n"
cd $DATAGUN_DIR
./bin/qgtunnel $DATAGUN_VIRTUALENV ./extract.py -C ./config/gapps.json
printf "\n"

cd $HOME

printf "Exporting existing users from Google to $GAM_USERS_EXPORT_FILE\n"
gam print users domain $GOOGLE_STUDENTS_DOMAIN suspended > $GAM_USERS_EXPORT_FILE
printf "\n"

printf "Exporting existing admins from Google to $GAM_ADMINS_EXPORT_FILE\n"
gam print admins role "Reset Student PW" > $GAM_ADMINS_EXPORT_FILE
printf "\n"

$GOOGLESYNC_VIRTUALENV $PROJECT_DIR/prep-gam-files.py

printf "Creating users..."
for i in $PROJECT_DIR/data/user_create_*.csv; do
    if [ -f $i ]; then
        printf "\n$i\n"

        filename=$(basename -- "$i")
        filename="${filename%.*}"

        gam csv $i \
        gam create \
            user ~email \
            firstname ~firstname \
            lastname ~lastname \
            suspended ~suspended_x \
            org ~org \
            password ~password \
            changepassword ~changepassword \
                > $PROJECT_DIR/log/$filename.log \
                2> $PROJECT_DIR/log/$filename-error.log
    else
        printf "\nNo users to create!"
    fi
done
printf "\n\n"

printf "Updating users w/ pw..."
for i in $PROJECT_DIR/data/user_update_pw_*.csv; do
    if [ -f $i ]; then
        printf "\n$i\n"
        
        filename=$(basename -- "$i")
        filename="${filename%.*}"

        gam csv $i \
        gam update \
            user ~primaryEmail \
            firstname ~firstname \
            lastname ~lastname \
            suspended ~suspended_x \
            org ~org \
            password ~password \
                > $PROJECT_DIR/log/$filename.log \
                2> $PROJECT_DIR/log/$filename-error.log
    else
        printf "\nNo users to update w/ pw!"
    fi
done
printf "\n\n"

printf "Updating users w/o pw..."
for i in $PROJECT_DIR/data/user_update_nopw_*.csv; do
    if [ -f $i ]; then
        printf "\n$i\n"
        
        filename=$(basename -- "$i")
        filename="${filename%.*}"

        gam csv $i \
        gam update \
            user ~primaryEmail \
            firstname ~firstname \
            lastname ~lastname \
            suspended ~suspended_x \
            org ~org \
                > $PROJECT_DIR/log/$filename.log \
                2> $PROJECT_DIR/log/$filename-error.log
    else
        printf "\nNo users to update w/o pw!"
    fi
done
printf "\n\n"

printf "Syncing user group membership...\n"
for i in $PROJECT_DIR/data/group_*.csv; do
    if [ -f $i ]; then
        filename=$(basename -- "$i")
        filename="${filename%.*}"

        gam csv $i \
        gam update \
            group ~group_email \
            sync member notsuspended nomail \
            ou_and_children "/Students/~~region~~"
                > $PROJECT_DIR/log/$filename.log \
                2> $PROJECT_DIR/log/$filename-error.log
    fi
done
printf "\n\n"

printf "Updating Reset Student PW admins..."
for i in $PROJECT_DIR/data/admin_create_*.csv; do
    if [ -f $i ]; then
        filename=$(basename -- "$i")
        filename="${filename%.*}"

        gam csv $i \
        gam create \
            admin ~user \
            "Reset Student PW" \
            org_unit "~~OU~~" \
                > $PROJECT_DIR/log/$filename.log \
                2> $PROJECT_DIR/log/$filename-error.log
    fi
done
