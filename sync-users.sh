export FILEPATH=$(realpath $0)
export PROJECT_DIR=$(dirname $FILEPATH)

if [ -f $PROJECT_DIR/.env ]; then
    . $PROJECT_DIR/.env
fi

mkdir -p $PROJECT_DIR/data
mkdir -p $PROJECT_DIR/log

printf "Exporting existing users from Google to $GAM_USERS_EXPORT_FILE\n"
gam print users domain $GOOGLE_STUDENTS_DOMAIN suspended > $GAM_USERS_EXPORT_FILE
printf "\n"

python $PROJECT_DIR/prep-gam-user-files.py

printf "Creating users..."
for i in $PROJECT_DIR/data/create_*.csv; do
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
for i in $PROJECT_DIR/data/update_pw_*.csv; do
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
for i in $PROJECT_DIR/data/update_nopw_*.csv; do
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

echo Adding students to groups...
gam update group group-students-miami@teamstudents.org sync member notsuspended nomail ou_and_children "/Students/Miami" > ./log/update_group_students_miami.log
gam update group group-students-camden@teamstudents.org sync member notsuspended nomail ou_and_children "/Students/KCNA" > ./log/update_group_students_camden.log
gam update group group-students-newark@teamstudents.org sync member notsuspended nomail ou_and_children "/Students/TEAM" > ./log/update_group_students_newark.log
