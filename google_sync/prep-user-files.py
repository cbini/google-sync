import os
import pathlib

import pandas as pd

GAM_USERS_EXPORT_FILE = os.getenv("GAM_USERS_EXPORT_FILE").replace("$HOME", "~")
DB_USERS_EXPORT_FILE = os.getenv("DB_USERS_EXPORT_FILE").replace("$HOME", "~")

PROJECT_PATH = pathlib.Path(__file__).absolute().parent


def split_and_save(df, group_col, base_filename):
    print(f"Saving {base_filename} files...")
    if df.shape[0] > 0:
        for v, d in df.groupby(group_col):
            data_path = PROJECT_PATH / "data" / "users" / v.lower()
            if not data_path.exists():
                data_path.mkdir(parents=True)

            filepath = data_path / f"{base_filename}.csv"
            d.to_csv(filepath, index=False)
            print(f"\t{filepath}")
        print()
    else:
        print(f"\tNo {base_filename} records to save!\n")


def main():
    pd.options.mode.chained_assignment = None

    # load database export into df
    print("Loading users from database...\n")
    db_users_df = pd.read_json(DB_USERS_EXPORT_FILE)

    # load existing users into df
    print("Loading users from GAM...\n")
    gam_users_df = pd.read_csv(GAM_USERS_EXPORT_FILE)

    # join the dataframes on google email
    print("Matching users from database to Google...\n")
    users_merge_df = pd.merge(
        db_users_df,
        gam_users_df,
        how="left",
        left_on="email",
        right_on="primaryEmail",
    )
    users_merge_df["google_exists"] = users_merge_df.primaryEmail.apply(pd.notnull)
    users_merge_df["suspended_x_bool"] = users_merge_df.suspended_x.apply(
        lambda x: True if x == "on" else False
    )

    # filter out completely inactive
    users_merge_df = users_merge_df[
        ~((users_merge_df.suspended_x == "on") & (users_merge_df.suspended_y))
    ]

    # users to CREATE
    users_create_df = users_merge_df[~users_merge_df.google_exists]
    users_create_df = users_create_df[users_create_df.suspended_x == "off"]
    split_and_save(users_create_df, "region", "user_create")

    # users to UPDATE (all)
    users_update_df = users_merge_df[
        (users_merge_df.google_exists)
        & (
            (users_merge_df["firstname"] != users_merge_df["name.givenName"])
            | (users_merge_df["lastname"] != users_merge_df["name.familyName"])
            | (users_merge_df["org"] != users_merge_df["orgUnitPath"])
            | (users_merge_df["suspended_x_bool"] != users_merge_df["suspended_y"])
        )
    ]
    users_update_df["changepassword"] = "off"

    # users to UPDATE (with password)
    users_update_df_pw = users_update_df[users_update_df.school_level == "ES"]
    split_and_save(users_update_df_pw, "region", "user_update_pw")

    # users to UPDATE (password)
    users_update_df_nopw = users_update_df[
        users_update_df.school_level.isin(["MS", "HS", "OD"])
    ]
    split_and_save(users_update_df_nopw, "region", "user_update_nopw")

    # group SYNC
    group_df = users_merge_df[["group_email", "region"]].drop_duplicates()
    split_and_save(group_df, "region", "group")


if __name__ == "__main__":
    main()
