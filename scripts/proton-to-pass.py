import csv
import os


# Function to sanitize names to be compatible with `pass`
def sanitize_name(name):
    return name.replace(" ", "_").replace("/", "_").lower()


# Open the CSV file
with open("/home/hugob/Downloads/Proton Pass_export_2024-08-12.csv", "r") as file:
    reader = csv.DictReader(file)
    for row in reader:
        service_name = sanitize_name(row["name"])
        username = row["username"]
        password = row["password"]
        url = row["url"]
        note = row["note"]
        totp = row["totp"]

        # Prepare the content for the pass entry
        pass_entry = ""
        if username:
            pass_entry += f"username: {username}\n"
        if password:
            pass_entry += f"password: {password}\n"
        if url:
            pass_entry += f"url: {url}\n"
        if note:
            pass_entry += f"note: {note}\n"
        if totp:
            pass_entry += f"totp: {totp}\n"

        # Only insert the entry if there's something to store
        if pass_entry.strip():
            os.system(f'echo "{pass_entry.strip()}" | pass insert -m {service_name}')
