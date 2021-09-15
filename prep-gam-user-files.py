import os
import pathlib

import pandas as pd

# GAM_USERS_EXPORT_FILE = os.getenv("GAM_USERS_EXPORT_FILE")
# DB_USERS_EXPORT_FILE = os.getenv("DB_USERS_EXPORT_FILE")
DB_USERS_EXPORT_FILE = (
    "/home/cbini/projects/datagun/data/gapps/gapps_users_students.json"
)
GAM_USERS_EXPORT_FILE = (
    "/home/cbini/projects/google-sync/data/gam_users_teamstudents.csv"
)

PROJECT_PATH = pathlib.Path(__file__).absolute().parent


def split_and_save(df, group_col, base_filename):
    if df.shape[0] > 0:
        print(f"Saving {base_filename} files...")
        for v, d in df.groupby(group_col):
            filepath = PROJECT_PATH / "data" / f"{base_filename}_{v.lower()}.csv"
            d.to_csv(filepath, index=False)
            print(f"\t{filepath}")
        print()
    else:
        print(f"No {base_filename} records to save!\n")


pd.options.mode.chained_assignment = None

# load existing users into df
print("Loading users from GAM...\n")
gam_students_df = pd.read_csv(GAM_USERS_EXPORT_FILE)

# load database export into df
print("Loading users from database...\n")
db_students_df = pd.read_json(DB_USERS_EXPORT_FILE)

# join the dataframes on google email
print("Matching users from database to Google...\n")
merge_students_df = pd.merge(
    db_students_df,
    gam_students_df,
    how="left",
    left_on="email",
    right_on="primaryEmail",
)
merge_students_df["google_exists"] = merge_students_df.primaryEmail.apply(pd.notnull)

# filter out completely inactive
merge_students_df = merge_students_df[
    ~((merge_students_df.suspended_x == "on") & (merge_students_df.suspended_y == True))
]

# users to CREATE
create_df = merge_students_df[merge_students_df.google_exists == False]
create_df = create_df[create_df.suspended_x == "off"]
split_and_save(create_df, "region", "create")

# users to UPDATE (all)
update_df = merge_students_df[merge_students_df.google_exists == True]
update_df["changepassword"] = "off"

# users to UPDATE (with password)
update_df_pw = update_df[update_df.school_level == "ES"]
split_and_save(update_df_pw, "region", "update_pw")

# users to UPDATE (password)
update_df_nopw = update_df[update_df.school_level.isin(["MS", "HS", "OD"])]
split_and_save(update_df_nopw, "region", "update_nopw")
