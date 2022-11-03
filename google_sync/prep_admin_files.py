import os
import pathlib

import pandas as pd


def split_and_save(df, group_col, base_filename):
    script_dir = pathlib.Path(__file__).absolute().parent

    print(f"Saving {base_filename} files...")
    if df.shape[0] > 0:
        for v, d in df.groupby(group_col):
            admins_data_dir = script_dir / "data" / "admins" / v.lower()
            if not admins_data_dir.exists():
                admins_data_dir.mkdir(parents=True)

            filepath = admins_data_dir / f"{base_filename}.csv"
            d.to_csv(filepath, index=False)
            print(f"\t{filepath}")
        print()
    else:
        print(f"\tNo {base_filename} records to save!\n")


def main():
    pd.options.mode.chained_assignment = None

    # load existing admins into df
    print("Loading admins from database...\n")
    db_admins_df = pd.read_json(
        os.getenv("DB_ADMINS_EXPORT_FILE").replace("$HOME", "~")
    )

    # load db admins into df
    print("Loading admins from GAM...\n")
    gam_admins_df = pd.read_csv(
        os.getenv("GAM_ADMINS_EXPORT_FILE").replace("$HOME", "~")
    )
    gam_admins_df["assignedToUser_lower"] = gam_admins_df["assignedToUser"].str.lower()

    # join the dataframes on google email and OU
    print("Matching admins from database to Google...\n")
    admins_merge_df = pd.merge(
        db_admins_df,
        gam_admins_df[["assignedToUser", "assignedToUser_lower", "orgUnit"]],
        how="left",
        left_on=["user", "OU"],
        right_on=["assignedToUser_lower", "orgUnit"],
    )
    admins_merge_df["google_exists"] = admins_merge_df.assignedToUser.apply(pd.notnull)

    # admins to CREATE
    admins_create_df = admins_merge_df[~admins_merge_df.google_exists]
    split_and_save(admins_create_df, "region", "admin_create")


if __name__ == "__main__":
    main()
