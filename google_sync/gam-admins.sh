#!/bin/bash

function gam() { "${HOME}/bin/gam/gam" "$@"; }

FILEPATH=$(realpath "${0}")
PROJECT_DIR=$(dirname "${FILEPATH}")
export PROJECT_DIR

printf "%s\n" "${PROJECT_DIR}"
mkdir -p "${PROJECT_DIR}"/data/admins
mkdir -p "${PROJECT_DIR}"/log/admins

printf "Exporting existing admins from Google to %s\n" "${GAM_ADMINS_EXPORT_FILE}"
gam print admins role "Reset Student PW" >"${GAM_ADMINS_EXPORT_FILE}"
printf "\n"

printf "Transforming final sync file\n"
pdm run prep-admins
printf "\n"

for dir in "${PROJECT_DIR}"/data/admins/*/; do
	dir=${dir%*/}
	region=${dir##*/}

	mkdir -p "${PROJECT_DIR}"/data/admins/"${region}"
	mkdir -p "${PROJECT_DIR}"/log/admins/"${region}"

	printf "%s - Creating Reset Student PW admins...\n" "${region}"
	admin_file=${dir}admin_create.csv
	if [[ -f ${admin_file} ]]; then
		filename=$(basename -- "${admin_file}")
		filename="${filename%.*}"

		gam csv "${admin_file}" \
			gam create \
			admin ~user \
			"Reset Student PW" \
			org_unit ~OU

		rm "${admin_file}"
	else
		printf "\tNo admins to create!\n"
	fi
	printf "\n"
done
