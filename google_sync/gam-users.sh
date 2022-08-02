function gam() { "$HOME/bin/gam/gam" "$@" ; }

export FILEPATH=$(realpath $0)
export PROJECT_DIR=$(dirname $FILEPATH)

export GAM_THREADS=$GAM_THREADS

mkdir -p $PROJECT_DIR/data/users
mkdir -p $PROJECT_DIR/log/users

printf "Exporting existing users from Google to ${GAM_USERS_EXPORT_FILE}\n"
gam print users domain \
    $GOOGLE_STUDENTS_DOMAIN \
    firstname lastname ou suspended \
        > $GAM_USERS_EXPORT_FILE
printf "\n"

printf "Transforming final sync file\n"
pdm run prep-users
printf "\n"

# setup
for dir in $PROJECT_DIR/data/users/*/;
do
    region=${dir##*/}
    mkdir -p $PROJECT_DIR/data/users/$region
    mkdir -p $PROJECT_DIR/log/users/$region
done    

# create new
for dir in $PROJECT_DIR/data/users/*/;
do
    printf "${dir} - Creating users...\n"
    create_file=${dir}user_create.csv
    if [ -f $create_file ]; then
        printf "$create_file\n"

        filename=$(basename -- "$create_file")
        filename="${filename%.*}"

        gam csv $create_file \
        gam create \
            user ~email \
            firstname ~firstname \
            lastname ~lastname \
            suspended ~suspended_x \
            org ~org \
            password ~password \
            changepassword ~changepassword

        rm $create_file
    else
        printf "\tNo users to create!\n"
    fi
    printf "\n"
done    

# update existing
for dir in $PROJECT_DIR/data/users/*/;
do
    printf "${dir} - Updating users w/o pw...\n"
    update_file=${dir}user_update_nopw.csv
    if [ -f $update_file ]; then
        printf "$update_file\n"

        filename=$(basename -- "$update_file")
        filename="${filename%.*}"

        gam csv $update_file \
        gam update \
            user ~primaryEmail \
            firstname ~firstname \
            lastname ~lastname \
            suspended ~suspended_x \
            org ~org

        rm $update_file
    else
        printf "\tNo users to update w/o pw!\n"
    fi
    printf "\n"
done

# sync groups
for dir in $PROJECT_DIR/data/users/*/;
do
    printf "${dir} - Syncing user group membership...\n"
    group_file=${dir}group.csv
    if [ -f $group_file ]; then
        filename=$(basename -- "$group_file")
        filename="${filename%.*}"

        gam csv $group_file \
        gam update \
            group ~group_email \
            sync member notsuspended nomail \
            ou_and_children "/Students/~~region~~"
    fi
    printf "\n"
done
