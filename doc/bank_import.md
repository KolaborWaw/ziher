# Automatic Bank Data Import (Elixir) in ZiHeR

## General Information

The automatic bank data import functionality allows ZiHeR system superadministrators to import bank transactions directly from Elixir format files into unit bank journals. This functionality is available only to users with superadministrator privileges.

## For Superadministrators

### Unit Configuration

1. Go to "Administration" -> "Units"
2. Edit the selected unit
3. Enter the unit's bank account number
4. Check "Automatic bank import (Elixir)" if you want to enable automatic data import for this unit
5. Save changes

### Managing Bank Account Numbers

1. Go to "Administration" -> "Bank Import (Elixir)"
2. Click "Manage account numbers"
3. You can:
   - Load a CSV file with unit codes and account numbers (format: `unit_code,account_number`)
   - Browse the list of units and their account numbers

### Importing Elixir Data

1. Go to "Administration" -> "Bank Import (Elixir)"
2. Click "Import Elixir data"
3. Select Elixir files to import (you can select multiple files at once)
4. Click "Import data"

Important information:
- The filename must contain the unit's bank account number
- The unit must have automatic bank data import enabled
- Import is only possible to open bank journals for the current year
- Only transactions from the current year are imported

### Deleting Entries from the Bank Journal

1. Go to "Administration" -> "Bank Import (Elixir)"
2. Find the unit in the list and click "Delete entries from [year]"
3. Confirm the operation by typing "DELETE ALL ENTRIES" in the confirmation field
4. Click "I confirm deletion of all entries"

## For Users

Users do not have direct access to the bank data import function. However, they can:

1. View entries in the bank journal that were automatically imported
2. Edit imported entries (if they have appropriate permissions)
3. See that the unit has automatic bank data import enabled (informational only)

## Elixir File Structure

Elixir files should have the following structure:
- Format: columns separated by commas, text values in quotes
- Column 1: Transaction type (111 = inflow, 222 = outflow)
- Column 2: Date in YYYYMMDD format
- Column 3: Amount in cents
- Columns 12-13: Transaction title/description
- Column 14: Unique transaction identifier (used as document number)

## Security

The system implements the following security measures:
1. Only superadministrators have access to the import function
2. Files are validated for format and content
3. Import is only possible to open bank journals
4. Deleting entries requires additional confirmation
5. All operations are recorded in the audit log

## Test Scenarios (UAT)

### Scenario 1: Unit Configuration
1. Log in as superadmin
2. Go to edit unit
3. Enter account number and check auto-import option
4. Verify that changes were saved

### Scenario 2: Import CSV File with Account Numbers
1. Prepare a CSV file with unit codes and account numbers
2. Log in as superadmin
3. Go to manage account numbers
4. Load CSV file
5. Verify that account numbers have been updated

### Scenario 3: Import Elixir Data
1. Prepare an Elixir file with transactions
2. Log in as superadmin
3. Go to Elixir data import
4. Load Elixir file
5. Check if transactions were imported to the appropriate bank journal

### Scenario 4: Delete Entries from Bank Journal
1. Log in as superadmin
2. Go to bank account management
3. Click "Delete entries" for the selected unit
4. Confirm the operation
5. Check if entries were deleted

### Scenario 5: Attempt to Import to a Closed Journal
1. Close the bank journal for the selected unit
2. Log in as superadmin
3. Try to import Elixir data
4. Check if the system displays an appropriate error message 