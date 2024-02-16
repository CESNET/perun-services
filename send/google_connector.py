import secrets
import string
import time
import uuid

from google.oauth2 import service_account
from googleapiclient.discovery import build

GROUPS_COLUMN_NAMES = ["email", "name", "[]members"]
DRIVES_COLUMN_NAMES = ["name", "[]members"]
USERS_COLUMN_NAMES = ["email", "givenName", "familyName", "suspended"]


def prepare_credentials(service_file, scopes, delegate):
    """
    Prepares credentials object passed to services
    :param service_file: file containing service account json
    :param scopes: scopes
    :param delegate: we'll be acting on behalf of this user
    :return: prepared credentials
    """
    config = service_account.Credentials.from_service_account_file(
        service_file, scopes=scopes
    )
    credentials_delegated = config.with_subject(delegate)
    return credentials_delegated


def generate_random_password():
    """
    A password can contain any combination of ASCII characters, and must be between 8-100 characters.
    :return: random password
    """
    characters = string.ascii_letters + string.digits + string.punctuation
    length = secrets.choice(range(8, 100))
    password = "".join(secrets.choice(characters) for _ in range(length))

    return password


def make_full_name(given_name, family_name):
    """
    Joins given name and family name to fullname, or uses only one of them, if the other is not available
    :return: full name or empty string, if no value can be used
    """
    if given_name and family_name:
        return f"{given_name} {family_name}"
    if given_name or family_name:
        return given_name if given_name else family_name
    return ""


def parse_domain(gen_folder, service_name):
    """
    Reads the content of the generated domain file
    :param gen_folder: path to the folder with the generated input files
    :param service_name: name of service to
    :return: domain, or fail with error
    """
    file_path = f"{gen_folder}/{service_name}_domain"
    try:
        with open(file_path) as file:
            lines = file.readlines()

            if len(lines) == 1:
                return lines[0].strip()
            else:
                raise ValueError("Domain file does not contain exactly one line.")
    except FileNotFoundError as e:
        raise FileNotFoundError(f"The file '{file_path}' does not exist.") from e
    except Exception as e:
        raise Exception(
            f"An error occurred while opening the domain file: {str(e)}"
        ) from e


class GoogleConnector:
    def __init__(self, service_file, scopes, delegate, domain, debug, dry_run):
        self.credentials = prepare_credentials(service_file, scopes, delegate)
        self.delegate = delegate
        self.domain = domain
        self.debug = debug
        self.dry_run = dry_run
        self.admin_directory = None
        self.drive_service = None
        # === statistics ===
        self.groups_updated = 0
        self.groups_created = 0
        self.groups_removed = 0
        self.memberships_updated = 0
        self.drives_created = 0
        self.drives_removed = 0
        self.permissions_updated = 0
        self.users_created = 0
        self.users_updated = 0
        self.users_removed = 0

    def print_debug(self, msg):
        if self.debug:
            print(msg)

    def get_admin_directory(self):
        if not self.admin_directory:
            self.admin_directory = build(
                "admin", "directory_v1", credentials=self.credentials
            )
        return self.admin_directory

    def get_drive_service(self):
        if not self.drive_service:
            self.drive_service = build("drive", "v3", credentials=self.credentials)
        return self.drive_service

    def fetch_groups(self):
        """
        Fetches groups from Google that belong to the domain
        :return: fetched groups
        """
        self.print_debug("Fetching groups")
        service = self.get_admin_directory()
        results = service.groups().list(domain=self.domain).execute()
        their_groups = [] if results.get("groups") is None else results.get("groups")
        while results.get("nextPageToken"):
            results = (
                service.groups()
                .list(domain=self.domain, pageToken=results.get("nextPageToken"))
                .execute()
            )
            their_groups.extend(results.get("groups"))

        self.print_debug(f"Fetched {len(their_groups)} groups.")
        return their_groups

    def fetch_drives(self):
        """
        Fetches drives from Google
        :return: fetched drives
        """
        self.print_debug("Fetching drives")
        service = self.get_drive_service()
        results = service.teamdrives().list(useDomainAdminAccess=True).execute()
        their_drives = (
            [] if results.get("teamDrives") is None else results.get("teamDrives")
        )
        while results.get("nextPageToken"):
            results = (
                service.teamdrives()
                .list(useDomainAdminAccess=True, pageToken=results.get("nextPageToken"))
                .execute()
            )
            their_drives.extend(results.get("teamDrives"))

        self.print_debug(f"Fetched {len(their_drives)} drives.")
        return their_drives

    def fetch_members(self, group_mail):
        """
        Fetches members of a group in Google using its group mail
        :param group_mail: group mail used as identifier
        :return: fetched members
        """
        self.print_debug(f"Fetching members of group {group_mail}")
        service = self.get_admin_directory()
        results = service.members().list(groupKey=group_mail).execute()
        their_members = [] if results.get("members") is None else results.get("members")
        while results.get("nextPageToken"):
            results = (
                service.members()
                .list(groupKey=group_mail, pageToken=results.get("nextPageToken"))
                .execute()
            )
            their_members.extend(results.get("members"))

        self.print_debug(f"Fetched {len(their_members)} members.")
        return their_members

    def fetch_users(self):
        """
        Fetches users in Google from specified domain
        :return: fetched users
        """
        self.print_debug("Fetching users")
        service = self.get_admin_directory()
        results = service.users().list(domain=self.domain).execute()
        their_users = [] if results.get("users") is None else results.get("users")
        while results.get("nextPageToken"):
            results = (
                service.users()
                .list(domain=self.domain, pageToken=results.get("nextPageToken"))
                .execute()
            )
            their_users.extend(results.get("users"))

        self.print_debug(f"Fetched {len(their_users)} users.")
        return their_users

    def fetch_permissions(self, drive):
        """
        Fetches permissions for team drive.
        :param drive: fetched drive to get permissions for
        :return: fetched permissions
        """
        self.print_debug(f"Fetching permissions of team drive {drive['name']}")
        service = self.get_drive_service()
        results = (
            service.permissions()
            .list(
                fileId=drive["id"],
                fields="kind,nextPageToken,permissions(id,type,role,emailAddress)",
                useDomainAdminAccess=True,
                supportsTeamDrives=True,
            )
            .execute()
        )
        permissions = (
            [] if results.get("permissions") is None else results.get("permissions")
        )
        while results.get("nextPageToken"):
            results = (
                service.permissions()
                .list(
                    fileId=drive["id"],
                    fields="kind,nextPageToken,permissions(id,type,role,emailAddress)",
                    useDomainAdminAccess=True,
                    supportsTeamDrives=True,
                    pageToken=results.get("nextPageToken"),
                )
                .execute()
            )
            permissions.extend(results.get("permissions"))

        self.print_debug(f"Fetched {len(permissions)} permissions.")
        return permissions

    def remove_group(self, google_group):
        """
        Removes the group in Google
        :param google_group: Group to remove
        """
        self.print_debug(f"Removing group: {google_group.get('name')}")
        if not self.dry_run:
            service = self.get_admin_directory()
            service.groups().delete(groupKey=google_group["email"]).execute()

    def remove_drive(self, google_drive):
        """
        Removes team drive with given name in Google
        :param google_drive: drive to remove
        """
        self.print_debug(f"Removing drive: {google_drive['name']}")
        if not self.dry_run:
            service = self.get_drive_service()
            service.teamdrives().delete(teamDriveId=google_drive["id"]).execute()

    def update_group(self, google_group, our_group):
        """
        Updates the group in Google, if the name is different
        :param google_group: group to update
        :param our_group: our group info
        :return: True if group updated, False otherwise
        """
        if our_group["name"] and google_group["name"] != our_group["name"]:
            self.print_debug(
                f"Updating group name '{google_group['name']}' to '{our_group['name']}'"
            )
            if not self.dry_run:
                service = self.get_admin_directory()
                service.groups().update(
                    groupKey=our_group["email"], body={"name": our_group["name"]}
                ).execute()
                return True
        return False

    def create_group(self, our_group):
        """
        Creates the group in Google
        :param our_group: dictionary entry containing group name and email
        :return: response
        """
        self.print_debug(f"Creating group: {our_group['email']}")
        if not self.dry_run:
            service = self.get_admin_directory()
            group_body = {"email": our_group["email"], "name": our_group["name"]}
            return service.groups().insert(body=group_body).execute()

    def create_drive(self, drive_name):
        """
        Creates the team drive in Google
        :param drive_name: name of the team drive
        :return: response
        """
        self.print_debug(f"Creating drive: {drive_name}")
        if not self.dry_run:
            service = self.get_drive_service()
            drive_body = {"name": drive_name}
            return (
                service.teamdrives()
                .create(body=drive_body, requestId=uuid.uuid4())
                .execute()
            )

    def insert_member(self, group_mail, member_mail):
        """
        Inserts missing member to Google group
        :param group_mail: Mail identifier of the group
        :param member_mail: User mail to be added as member
        """
        self.print_debug(f"Inserting member: {member_mail}")
        if not self.dry_run:
            service = self.get_admin_directory()
            new_member = {
                "email": member_mail,
            }
            service.members().insert(groupKey=group_mail, body=new_member).execute()

    def remove_member(self, group_mail, member_mail):
        """
        Removes redundant member from Google group
        :param group_mail: Mail identifier of the group
        :param member_mail: Mail of the user to be removed
        """
        self.print_debug(f"Removing member: {member_mail}")
        if not self.dry_run:
            service = self.get_admin_directory()
            service.members().delete(
                groupKey=group_mail, memberKey=member_mail
            ).execute()

    def update_members(self, our_group, their_members):
        """
        Removes and adds members to Google group
        :param our_group: dictionary entry of our group containing members
        :param their_members: the fetched members
        :return: True if members were updated, False otherwise
        """
        updated = False
        for our_member_mail in our_group["members"]:
            their_member = next(
                (
                    m
                    for m in their_members
                    if m["email"].lower() == our_member_mail.lower()
                ),
                None,
            )
            if not their_member:
                updated = True
                self.insert_member(our_group["email"], our_member_mail)

        for their_member in their_members:
            our_member = next(
                (
                    m
                    for m in our_group["members"]
                    if m.lower() == their_member["email"].lower()
                ),
                None,
            )
            if not our_member:
                updated = True
                self.remove_member(our_group["email"], their_member["email"])

        return updated

    def add_permission(self, their_drive, member_mail):
        """
        Adds user an organizer permission to the team drive
        :param their_drive: fetched drive to add permission to
        :param member_mail: email of the member
        """
        self.print_debug(f"Adding permission for member: {member_mail}")
        if not self.dry_run:
            new_permission = {
                "type": "user",
                "role": "organizer",
                "emailAddress": member_mail,
            }
            service = self.get_drive_service()
            service.permissions().create(
                fileId=their_drive["id"],
                body=new_permission,
                supportsTeamDrives=True,
                useDomainAdminAccess=True,
            ).execute()

    def remove_permission(self, their_drive, member_mail, permission_id):
        """
        Removes user permission from a team drive
        :param their_drive: fetched drive to remove permissions from
        :param member_mail: mail of the user to be removed, for logging purposes
        :param permission_id: id of the permission to be removed
        """
        self.print_debug(f"Removing permission for member: {member_mail}")
        if not self.dry_run:
            service = self.get_drive_service()
            service.permissions().delete(
                fileId=their_drive["id"],
                permissionId=permission_id,
                supportsTeamDrives=True,
                useDomainAdminAccess=True,
            ).execute()

    def update_permissions(self, our_drive, their_drive, their_permissions):
        """
        Removes and adds permissions to the team drive
        :param our_drive: dictionary entry of the drive containing members
        :param their_drive: the fetched drive to update permissions in
        :param their_permissions: the fetched permissions
        :return: True if permissions were updated, False otherwise
        """
        updated = False
        for our_member_mail in our_drive["members"]:
            their_member = next(
                (
                    m
                    for m in their_permissions
                    if m["emailAddress"].lower() == our_member_mail.lower()
                ),
                None,
            )
            if not their_member:
                updated = True
                self.add_permission(their_drive, our_member_mail)

        for their_permission in their_permissions:
            if their_permission["emailAddress"].lower() == self.delegate.lower():
                # never remove service-account permission
                continue
            our_member = next(
                (
                    m
                    for m in our_drive["members"]
                    if m.lower() == their_permission["emailAddress"].lower()
                ),
                None,
            )
            if not our_member:
                updated = True
                self.remove_permission(
                    their_drive,
                    their_permission["emailAddress"],
                    their_permission["id"],
                )
        return updated

    def create_user(self, our_user):
        """
        Creates user in Google
        :param our_user: dictionary entry containing first name, last name, email and suspension flag
        """
        self.print_debug(f"Creating user: {our_user['email']}")
        if not self.dry_run:
            service = self.get_admin_directory()
            user_body = {
                "name": {
                    "givenName": our_user["givenName"],
                    "familyName": our_user["familyName"],
                    "fullName": make_full_name(
                        our_user["givenName"], our_user["familyName"]
                    ),
                },
                "primaryEmail": our_user["email"],
                "password": generate_random_password(),
            }
            if our_user["suspended"]:
                user_body["suspended"] = True
            service.users().insert(
                body=user_body, fields="primaryEmail,name,suspended"
            ).execute()

    def delete_user(self, their_user):
        """
        Deletes user in Google
        :param their_user: fetched user to be deleted
        """
        self.print_debug(f"Deleting user: {their_user['primaryEmail']}")
        if not self.dry_run:
            service = self.get_admin_directory()
            service.users().delete(userKey=their_user["id"]).execute()

    def update_user(self, our_user, their_user):
        """
        Updates user in Google if the name does not match or the user should be (un)suspended
        :param our_user: dictionary entry containing username, givenName, familyName, email and suspension flag
        :param their_user: fetched user to compare properties with
        """
        our_user_suspended = bool(our_user.get("suspended"))
        their_user_suspended = their_user.get("suspended")
        our_user_full_name = make_full_name(
            our_user["givenName"], our_user["familyName"]
        )
        updated = False
        if (
            our_user["givenName"] != their_user.get("name", {}).get("givenName")
            or our_user["familyName"] != their_user.get("name", {}).get("familyName")
            or our_user_full_name != their_user.get("name", {}).get("fullName")
            or our_user_suspended != their_user_suspended
        ):
            updated = True
            self.print_debug(f"Updating user: {our_user['email']}")
            if not self.dry_run:
                user_body = {
                    "name": {
                        "givenName": our_user["givenName"],
                        "familyName": our_user["familyName"],
                        "fullName": our_user_full_name,
                    }
                }
                # Set (un)suspend flag only if it had changed
                if our_user_suspended != their_user_suspended:
                    user_body["suspended"] = our_user_suspended
                service = self.get_admin_directory()
                service.users().update(
                    userKey=our_user["email"], body=user_body
                ).execute()
        return updated

    def suspend_user(self, their_user):
        """
        Suspends user in Google
        :param their_user: Fetched user to be suspended
        """
        self.print_debug(f"Suspending user: {their_user.get('primaryEmail')}")
        if not self.dry_run:
            user_body = {"suspend": True}
            service = self.get_admin_directory()
            service.users().update(userKey=their_user["id"], body=user_body).execute()

    def resolve_team_drives(self, our_drives, their_drives, allow_delete_teamdrive):
        """
        This method solves team drives creation, removal and permissions updates.
        :param our_drives: parsed input data
        :param their_drives: fetched data from Google
        :param allow_delete_teamdrive: if true, redundant drives get deleted, if false, just all permissions removed
        """
        for our_drive_name, our_drive_info in our_drives.items():
            their_drive = next(
                filter(lambda d: our_drive_name == d.get("name"), their_drives),
                None,
            )
            their_permissions = []
            if not their_drive:
                their_drive = self.create_drive(our_drive_name)
                self.drives_created += 1
                time.sleep(2)  # wait for drive creation
            else:
                their_permissions = self.fetch_permissions(their_drive)
            if self.update_permissions(our_drive_info, their_drive, their_permissions):
                self.permissions_updated += 1

        for their_drive in their_drives:
            our_drive = next(
                filter(lambda g: g == their_drive["name"], our_drives.keys()), None
            )
            if not our_drive:
                if allow_delete_teamdrive:
                    self.remove_drive(their_drive)
                    self.drives_removed += 1
                else:
                    their_permissions = self.fetch_permissions(their_drive)
                    # never remove service-account permission
                    their_permissions = [
                        p
                        for p in their_permissions
                        if p["emailAddress"].lower() != self.delegate.lower()
                    ]
                    for permission in their_permissions:
                        self.remove_permission(
                            their_drive,
                            permission["emailAddress"],
                            permission["id"],
                        )
                    self.permissions_updated += 1 if len(their_permissions) else 0

    def resolve_groups(self, our_groups, their_groups):
        """
        This method solves groups creation, name update, groups removal and memberships updates.
        :param our_groups: parsed input data
        :param their_groups: fetched data from Google
        """
        for our_group_mail, our_group_info in our_groups.items():
            if len(our_group_mail.split("@")) != 2:
                print("Skipping group with invalid email: " + our_group_mail)
            elif our_group_mail.split("@")[1] != self.domain:
                print("Skipping group from different domain: " + our_group_mail)

            their_group = next(
                filter(
                    lambda g: g.get("email").lower() == our_group_mail.lower(),
                    their_groups,
                ),
                None,
            )
            their_members = []
            if not their_group:
                self.create_group(our_group_info)
                self.groups_created += 1
            else:
                if self.update_group(their_group, our_group_info):
                    self.groups_updated += 1
                their_members = self.fetch_members(our_group_mail)
            if self.update_members(our_group_info, their_members):
                self.memberships_updated += 1

        for their_group in their_groups:
            our_group_email = next(
                filter(
                    lambda our_group_email: our_group_email.lower()
                    == their_group.get("email").lower(),
                    our_groups.keys(),
                ),
                None,
            )
            if not our_group_email:
                self.remove_group(their_group)
                self.groups_removed += 1

    def resolve_users(self, our_users, their_users, allow_delete):
        """
        This method creates missing users, updates their info and removes or suspends them, based on configuration.
        New users in suspended state are not created!
        :param our_users: parsed input data
        :param their_users: fetched from Google
        :param allow_delete: True if users can be deleted, False if only suspended
        """
        for our_user_email, our_user_info in our_users.items():
            if len(our_user_email.split("@")) != 2:
                print("Skipping user with invalid email: " + our_user_email)
            if our_user_email.split("@")[1] != self.domain:
                print("Skipping user from different domain: " + our_user_email)
            their_user = next(
                filter(
                    lambda u: u.get("primaryEmail").lower() == our_user_email.lower(),
                    their_users,
                ),
                None,
            )
            if not their_user:
                # do not create suspended users
                our_user_suspended = bool(our_user_info.get("suspended"))
                if not our_user_suspended:
                    self.create_user(our_user_info)
                    self.users_created += 1
            else:
                if self.update_user(our_user_info, their_user):
                    self.users_updated += 1

        for their_user in their_users:
            our_user_email = next(
                filter(
                    lambda our_user_email: our_user_email.lower()
                    == their_user.get("primaryEmail").lower(),
                    our_users.keys(),
                ),
                None,
            )
            if not our_user_email:
                if allow_delete:
                    self.delete_user(their_user)
                    self.users_removed += 1
                elif not their_user["suspended"]:
                    self.suspend_user(their_user)
                    self.users_updated += 1
