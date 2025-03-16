# Technical Documentation for Bank Statement Import in Elixir Format

## Table of Contents
1. [Introduction](#introduction)
2. [Unit Configuration](#unit-configuration)
3. [Elixir File Format](#elixir-file-format)
4. [Import Process](#import-process)
5. [Troubleshooting](#troubleshooting)
6. [Audit Logs](#audit-logs)

## Introduction

The ZiHeR application enables automatic import of bank statements in Elixir format. This feature significantly accelerates data entry into the bank journal, particularly useful when handling a large number of transactions.

## Unit Configuration

To use automatic import, you need to:

1. Go to unit editing (Menu > Units > [selected unit] > Edit)
2. Enter the unit's bank account number
3. Check "Automatic bank loading (Elixir)"
4. Save changes

Alternatively, administrators can import account numbers for multiple units simultaneously:

1. Go to "Bank Import (Elixir)" section in the main menu
2. Select "Manage account numbers"
3. Upload a CSV file containing unit codes and account numbers

### CSV File Format for Account Numbers
```
unit_code,account_number
01ZGD,11114444555566667777888899
02ZGD,99998888777766665555444411
```

## Elixir File Format

Elixir files are text files containing bank transaction information. For the system to process the files correctly, the following rules must be followed:

1. The filename should include the unit's bank account number, e.g., `statement_11114444555566667777888899_20240315.csv`
2. The file should contain transactions in CSV format

### CSV File Structure
Each row of the file should include at least the following information:
- Transaction date
- Amount (with sign)
- Transfer title
- Sender/recipient
- Transaction reference number

### Example CSV Row
```
2024-03-15,123.45,"Membership fees","John Smith","11112222333344445555666677",REF123456789
```

## Import Process

1. Go to "Bank Import (Elixir)" section in the main menu
2. Select "Import Elixir data"
3. Upload an Elixir file (multiple files can be selected simultaneously)
4. The system automatically:
   - Recognizes the account number from the filename
   - Finds the corresponding unit
   - Imports transactions to the bank journal

### Important Information
- Import is only possible for units with auto_bank_import enabled
- If a bank journal for the given year doesn't exist, it will be created automatically
- Import is only possible to an open bank journal
- In case of file encoding issues, the system tries different encodings (Windows-1250, ISO-8859-2, CP852, UTF-8)

## Troubleshooting

### Common Issues and Solutions

1. **Issue:** The system doesn't recognize the account number
   **Solution:** Ensure the filename contains the full account number without spaces or other characters

2. **Issue:** Import ends with an encoding error
   **Solution:** Save the file in one of the supported encodings (UTF-8 recommended)

3. **Issue:** Message "Bank journal is closed"
   **Solution:** Open the bank journal for the given year

4. **Issue:** Message "No income or expense categories"
   **Solution:** Create categories for the current year

## Audit Logs

The system automatically records logs of all Elixir imports. Logs include information about:
- Import date and time
- User performing the import
- Uploaded file name
- Number of imported transactions
- Any errors that occurred

Administrators can view logs in the "Audit" section accessible from the main menu. 