credentials = {
    "destination_1": {
        "service_file": "/etc/perun/services/google_service_file",  # absolute path to generated JSON configuration (see google_service_file)
        "scopes": [
            "https://www.googleapis.com/auth/admin.directory.user",
            "https://www.googleapis.com/auth/admin.directory.user.readonly",
            "https://www.googleapis.com/auth/admin.directory.group",
            "https://www.googleapis.com/auth/admin.directory.group.member",
            "https://www.googleapis.com/auth/drive",
        ],
        "delegate": "user@domain.com",  # service account impersonates this user
        "allow_delete_teamdrive": False,  # True/False value determines if team drive should be deleted/kept without permissions
    }
}
