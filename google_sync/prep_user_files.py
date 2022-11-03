import os
import pathlib

import pandas as pd


def split_and_save(df, group_col, base_filename):
    script_dir = pathlib.Path(__file__).absolute().parent

    print(f"Saving {base_filename} files...")
    if df.shape[0] > 0:
        for v, d in df.groupby(group_col):
            users_data_dir = script_dir / "data" / "users" / v.lower()
            if not users_data_dir.exists():
                users_data_dir.mkdir(parents=True)

            filepath = users_data_dir / f"{base_filename}.csv"
            d.to_csv(filepath, index=False)
            print(f"\t{filepath}")
        print()
    else:
        print(f"\tNo {base_filename} records to save!\n")


def main():
    pd.options.mode.chained_assignment = None

    # load database export into df
    print("Loading users from database...\n")
    db_users_df = pd.read_json(os.getenv("DB_USERS_EXPORT_FILE").replace("$HOME", "~"))

    # load existing users into df
    print("Loading users from GAM...\n")
    gam_users_df = pd.read_csv(os.getenv("GAM_USERS_EXPORT_FILE").replace("$HOME", "~"))

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
    split_and_save(users_update_df, "region", "user_update")

    # group SYNC
    group_df = users_merge_df[["group_email", "region"]].drop_duplicates()
    split_and_save(group_df, "region", "group")


if __name__ == "__main__":
    main()
