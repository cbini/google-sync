#!/bin/bash

function gam() { "${HOME}/bin/gam/gam" "$@"; }

FILEPATH=$(realpath "${0}")
PROJECT_DIR=$(dirname "${FILEPATH}")
export PROJECT_DIR

printf "%s\n" "${PROJECT_DIR}"
mkdir -p "${PROJECT_DIR}"/data/users
mkdir -p "${PROJECT_DIR}"/log/users

printf "Exporting existing users from Google to %s\n" "${GAM_USERS_EXPORT_FILE}"
gam print users domain \
	"${GOOGLE_STUDENTS_DOMAIN}" \
	firstname lastname ou suspended \
	>"${GAM_USERS_EXPORT_FILE}"
printf "\n"

printf "Transforming final sync file\n"
pdm run prep-users
printf "\n"

# setup
for dir in "${PROJECT_DIR}"/data/users/*/; do
	region=${dir##*/}
	mkdir -p "${PROJECT_DIR}"/data/users/"${region}"
	mkdir -p "${PROJECT_DIR}"/log/users/"${region}"
done

# create new
for dir in "${PROJECT_DIR}"/data/users/*/; do
	printf "%s - Creating users...\n" "${dir}"
	create_file=${dir}user_create.csv
	if [[ -f ${create_file} ]]; then
		printf "%s\n" "${create_file}"

		filename=$(basename -- "${create_file}")
		filename="${filename%.*}"

		gam csv "${create_file}" \
			gam create \
			user ~email \
			firstname ~firstname \
			lastname ~lastname \
			suspended ~suspended_x \
			org ~org \
			password ~password \
			changepassword ~changepassword

		rm "${create_file}"
	else
		printf "\tNo users to create!\n"
	fi
	printf "\n"
done

# update existing
for dir in "${PROJECT_DIR}"/data/users/*/; do
	printf "%s - Updating users w/o pw...\n" "${dir}"
	update_file=${dir}user_update_nopw.csv
	if [[ -f ${update_file} ]]; then
		printf "%s\n" "${update_file}"

		filename=$(basename -- "${update_file}")
		filename="${filename%.*}"

		gam csv "${update_file}" \
			gam update \
			user ~primaryEmail \
			firstname ~firstname \
			lastname ~lastname \
			suspended ~suspended_x \
			org ~org

		rm "${update_file}"
	else
		printf "\tNo users to update w/o pw!\n"
	fi
	printf "\n"
done

# sync groups
for dir in "${PROJECT_DIR}"/data/users/*/; do
	printf "%s - Syncing user group membership...\n" "${dir}"
	group_file=${dir}group.csv
	if [[ -f ${group_file} ]]; then
		filename=$(basename -- "${group_file}")
		filename="${filename%.*}"

		gam csv "${group_file}" \
			gam update \
			group ~group_email \
			sync member notsuspended nomail \
			ou_and_children "/Students/~~region~~"
	fi
	printf "\n"
done
