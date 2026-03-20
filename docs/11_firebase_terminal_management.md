# Firebase Data Management via Terminal

This guide explains how to manage Firebase Realtime Database and Firestore data using the Firebase CLI. This is the primary method used by the AI assistant for seeding, purging, and verifying data.

## Realtime Database (RTDB)

### 1. Reading Data (`get`)
To view data at a specific path:
```bash
firebase database:get /path/to/data --project [PROJECT_ID]
```
- Returns `null` if the path does not exist.
- Returns a JSON object if data exists.

### 2. Writing/Overwriting Data (`set`)
To overwrite data at a path:
```bash
# Using a JSON file (Recommended for Windows)
firebase database:set /path/to/data data_file.json --project [PROJECT_ID] -f

# Direct JSON string (Be careful with escaping)
firebase database:set /path/to/data "{\"key\": \"value\"}" --project [PROJECT_ID] -f
```
- `-f` (or `--force`) bypasses the confirmation prompt.

### 3. Appending Data (`push`)
To add a new item to a list with a unique Firebase-generated ID:
```bash
firebase database:push /path/to/list data_file.json --project [PROJECT_ID]
```

### 4. Updating Specific Fields (`update`)
To update specific fields without overwriting the entire node:
```bash
firebase database:update /path/to/data "{\"status\": \"active\"}" --project [PROJECT_ID]
```

### 5. Deleting Data (`remove`)
To delete a node and all its children:
```bash
firebase database:remove /path/to/data --project [PROJECT_ID] -f
```

---

## 6. Advanced Querying & Filtering
For viewing large datasets efficiently:
```bash
# Order by child field and limit to 10 results
firebase database:get /users --orderBy "tokens" --limitToFirst 10

# Shallow read (keys only, no children) - Great for performance
firebase database:get / --shallow

# Filter by equality
firebase database:get /users --orderBy "status" --equalTo "active"
```

---

## 7. Backups & Exports
How to export your data for local testing or backup:
```bash
# Export entire RTDB to a JSON file
firebase database:get / > backup.json --project [PROJECT_ID]

# Import the backup (caution: overwrites)
firebase database:set / backup.json --project [PROJECT_ID] -f
```

---

## 8. Local Emulators
For local development without impacting production:
```bash
# Start the emulators
firebase emulators:start

# Run commands against your local emulator
# (Defaults to localhost ports)
firebase database:get / --project [PROJECT_ID] --instance [YOUR_EMULATOR_INSTANCE]
```

---

## 9. Security Rules
Deploy or view your database rules:
```bash
# Deploy latest rules defined in database.rules.json
firebase deploy --only database

# View currently active rules on the server
firebase database:rules:get --project [PROJECT_ID]
```

---

## 10. Cloud Functions Management
```bash
# Deploy all functions
firebase deploy --only functions

# Deploy a specific function
firebase deploy --only functions:onUserCreated

# Check function execution logs
firebase functions:log --project [PROJECT_ID]
```

---

## 11. Firestore Advanced
```bash
# Force document deletion
firebase firestore:delete users/UID --project [PROJECT_ID] -y

# Delete an entire collection recursively
firebase firestore:delete users --recursive --project [PROJECT_ID] -y

# Bulk export Firestore data (Requires GCP Storage bucket)
gcloud firestore export gs://[BUCKET_NAME]
```

---

## Windows-Specific Notes
- **STDIN Piping**: On Windows, piping JSON directly (`echo {} | firebase ...`) often fails or is unsupported by the CLI. **Always use a temporary `.json` file** for complex data structures.
- **Escaping**: If using direct strings, ensure double quotes are escaped: `"{\"key\": \"value\"}"`.
- **PowerShell vs CMD**: In PowerShell, some arguments with special characters might need extra quoting. `"`...`"` usually works best.

## Authentication & Projects
- **Login**: `firebase login`
- **Logout**: `firebase logout`
- **List Projects**: `firebase projects:list`
- **Switch Default**: `firebase use [PROJECT_ID]`

