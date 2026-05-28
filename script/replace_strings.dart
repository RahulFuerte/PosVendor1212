import 'dart:io';

void main() {
  File file = File('lib/view/home/screens/customer_list_screen.dart');
  String content = file.readAsStringSync();
  
  Map<String, String> replacements = {
    "'Import Customers'": "AppLocale.importCustomers.getString(context)",
    "'Need help with Excel format? View detailed instructions first.'": "AppLocale.needHelpWithExcelFormat.getString(context)",
    "'Skip Help'": "AppLocale.skipHelp.getString(context)",
    "'Show Help'": "AppLocale.showHelp.getString(context)",
    "'Importing customers...'": "AppLocale.importingCustomers.getString(context)",
    "'Processing \${file.name}'": "'\${AppLocale.processingFile.getString(context)}\${file.name}'",
    "'Invalid Excel format: Need at least Name and Phone columns'": "AppLocale.invalidExcelFormatNamePhone.getString(context)",
    "'Row \${i + 1}: Insufficient data (need at least Name and Phone)'": "'Row \${i + 1}\${AppLocale.insufficientDataNamePhone.getString(context)}'",
    "'Row \${i + 1}: Name and Phone are required'": "'Row \${i + 1}\${AppLocale.nameAndPhoneRequired.getString(context)}'",
    "'Row \${i + 1}: Invalid phone number format (\$phone)'": "'Row \${i + 1}\${AppLocale.invalidPhoneNumberFormat.getString(context)}\$phone)'",
    "'Row \${i + 1}: Duplicate phone number found (\$phone)'": "'Row \${i + 1}\${AppLocale.duplicatePhoneNumberFound.getString(context)}\$phone)'",
    "'Import completed!\\nSuccessful: \$successfulImports, Failed: \$failedImports'": "'\${AppLocale.importCompleted.getString(context)}\$successfulImports\${AppLocale.importFailedMsg.getString(context)}\$failedImports'",
    "'\\n\\nErrors:\\n\${errors.take(3).join('\\n')}'": "'\${AppLocale.errorsList.getString(context)}\${errors.take(3).join('\\n')}'",
    "'\\n...and \${errors.length - 3} more'": "'\${AppLocale.andMore.getString(context)}\${errors.length - 3}\${AppLocale.more.getString(context)}'",
    "'Import Complete'": "AppLocale.importComplete.getString(context)",
    "'Import Failed'": "AppLocale.importFailed.getString(context)",
    "'Would you like to sync the imported customers to the cloud?'": "AppLocale.syncImportedCustomers.getString(context)",
    "'Sync Now'": "AppLocale.syncNow.getString(context)",
    "'Download Sample Data'": "AppLocale.downloadSampleData.getString(context)",
    "'This will download a sample Excel template to your device.'": "AppLocale.downloadSampleDataDesc.getString(context)",
    "'After download, you can select this file when importing customers.'": "AppLocale.downloadSampleDataDesc2.getString(context)",
    "'Download'": "AppLocale.download.getString(context)",
    "'Downloading sample data...'": "AppLocale.downloadingSampleData.getString(context)",
    "'Please wait'": "AppLocale.pleaseWait.getString(context)",
    "'Permission Required'": "AppLocale.permissionRequired.getString(context)",
    "'Storage permission is required to save the file. Please enable it in settings.'": "AppLocale.storagePermissionRequired.getString(context)",
    "'Open Settings'": "AppLocale.openSettings.getString(context)",
    "'Storage permission denied'": "AppLocale.storagePermissionDenied.getString(context)",
    "'Sample download not available. Please create your own Excel template.'": "AppLocale.sampleDownloadNotAvailable.getString(context)",
    "'Could not access storage directory'": "AppLocale.couldNotAccessStorage.getString(context)",
    "'Downloaded: \$fileName\\nYou can now select this file for import'": "'\${AppLocale.downloadedMsg.getString(context)}\$fileName\${AppLocale.downloadedMsg2.getString(context)}'",
    "'Download failed: \${response.statusCode}'": "'\${AppLocale.downloadFailed.getString(context)}\${response.statusCode}'",
    "'Download error: \$e'": "'\${AppLocale.downloadError.getString(context)}\$e'",
    "'Excel Format Guide'": "AppLocale.excelFormatGuide.getString(context)",
    "'Your Excel file should have the following column structure:'": "AppLocale.excelColumnStructure.getString(context)",
    "'Column A: Customer Name (Required)'": "AppLocale.columnA.getString(context)",
    "'Column B: Phone Number (Required)'": "AppLocale.columnB.getString(context)",
    "'Column C: Address (Optional)'": "AppLocale.columnC.getString(context)",
    "'Column D: GST Number (Optional)'": "AppLocale.columnD.getString(context)",
    "'Example:'": "AppLocale.example.getString(context)",
    "'Note: Make sure to remove any extra columns or rows before uploading.'": "AppLocale.removeExtraColumnsRows.getString(context)",
    "'Note: If you have no data then download a sample data by clicking on the \"Download Sample\" button.'": "AppLocale.noDataDownloadSample.getString(context)",
    "'Download Sample'": "AppLocale.downloadSample.getString(context)",
    "'No customers to upload'": "AppLocale.noCustomersToUpload.getString(context)",
    "'Successfully uploaded \$successCount customers'": "'\${AppLocale.successfullyUploaded.getString(context)}\$successCount\${AppLocale.customersMsg.getString(context)}'",
    "'Error uploading: \$e'": "'\${AppLocale.errorUploading.getString(context)}\$e'",
    "'Are you sure you want to delete \${customer.name}? This action cannot be undone.'": "AppLocale.areYouSureDeleteCustomer.getString(context)",
    "'Customer deleted successfully'": "AppLocale.customerDeletedSuccessfully.getString(context)",
    "'Delete failed: \$e'": "'\${AppLocale.deleteFailed.getString(context)}\$e'",
    "'Customer updated successfully'": "AppLocale.customerUpdatedSuccessfully.getString(context)",
    "'Customer added successfully'": "AppLocale.customerAddedSuccessfully.getString(context)",
    "'Error updating customer: \$e'": "'\${AppLocale.errorUpdatingCustomer.getString(context)}\$e'",
    "'Error adding customer: \$e'": "'\${AppLocale.errorAddingCustomer.getString(context)}\$e'",
    "'Import from Excel'": "AppLocale.importFromExcel.getString(context)",
    "'Excel format help'": "AppLocale.excelFormatHelp.getString(context)",
    "\"No Edit Permission under current plan\"": "AppLocale.noEditPermissionMsg.getString(context)",
    "\"No Delete Permission under current plan\"": "AppLocale.noDeletePermissionMsg.getString(context)",
    "'Added: \${dateFormat.format(customer.createdAt ?? DateTime.now())}'": "'\${AppLocale.addedPrefix.getString(context)}\${dateFormat.format(customer.createdAt ?? DateTime.now())}'",
    "'GST: \${customer.gstNo}'": "'\${AppLocale.gstPrefix.getString(context)}\${customer.gstNo}'"
  };

  replacements.forEach((key, value) {
    content = content.replaceAll('const MyText(text: \$key', 'MyText(text: \$value');
    content = content.replaceAll('const MyText(\\n              text: \$key', 'MyText(\\n              text: \$value');
    content = content.replaceAll('const MyText(\\n                    text: \$key', 'MyText(\\n                    text: \$value');
    content = content.replaceAll(key, value);
  });

  // some more cleanup for 'const MyText'
  content = content.replaceAll(RegExp(r'const\s+MyText\(\s*text:\s*AppLocale'), 'MyText(text: AppLocale');

  file.writeAsStringSync(content);
}
