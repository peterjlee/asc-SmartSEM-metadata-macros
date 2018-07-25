/* This macro extracts the metadata from the TIFF file header of an Zeiss SEM image.
 it is based on the scale extracting macro here: https://rsb.info.nih.gov/ij/macros/SetScaleFromTiffTag.txt
 This requires the tiff_tags plugin written by Joachim Wesner that can be downloaded from http://rsbweb.nih.gov/ij/plugins/tiff-tags.html
 There is an example image available at http://rsbweb.nih.gov/ij/images/SmartSEMSample.tif
 See also the original Nabble post by Pablo Manuel Jais: http://imagej.1557.x6.nabble.com/Importing-SEM-images-with-scale-td3689900.html This version: https://rsb.info.nih.gov/ij/macros/SetScaleFromTiffTag.txt
 Original version v161101 Peter J. Lee
 v161105 expands comments
*/
macro "Export Carl Zeiss SEM metadata" {
	setBatchMode(true);
	hideResultsAs("hiddenResults"); /* A new results table will be used for this macro */
	/* Next obtain path+name of the active image to determine name and location for experted csv file */
	dir = getDirectory("image");
	if (dir=="") exit("path not available");
	name = getInfo("image.filename");
	if (name=="") exit("name not available");
	path = dir + name;
	fullTag = call("TIFF_Tags.getTag", path, 34118); /* 34118 is the tag that contains all the Carl Zeiss SmartSEM metadata */
	metaTagStart = indexOf(fullTag, "DP_ZOOM");
	tag = substring(fullTag, metaTagStart);
	/* the next lines edit the metatag for easier export - Edit this section if you want to retain DP, AP and SV prefixes */
	for (i=0; i<10; i++) tag = replace(tag, "  ", " ");
	tag = replace(tag, "DP_", "|DP_");
	tag = replace(tag, "AP_", "|AP_");
	tag = replace(tag, "SV_", "|SV_");
	metaArray = split(tag, "|");
	parameterArray = newArray(lengthOf(metaArray));
	valueArray =  newArray(lengthOf(metaArray));
	unitArray =  newArray(lengthOf(metaArray));
	for (i=0; i<lengthOf(metaArray); i ++) {
		metaArray[i] = substring(metaArray[i], indexOf(metaArray[i], " "));
		errorPos = indexOf(metaArray[i], " Error ");
		if (errorPos>0) metaArray[i] = replace(metaArray[i], "Error", "=");
		eqPos = indexOf(metaArray[i], "=");
		if (eqPos>0) {
			parameterArray[i] = substring(metaArray[i], 0, eqPos-1);
			valueArray[i] = substring(metaArray[i], eqPos+2);
		}
		else {
			parameterArray[i] = metaArray[i];
			valueArray[i] = "NA";
		}
		splitValue = split(valueArray[i]);
		if (lengthOf(splitValue)>0) valueArray[i] = splitValue[0];
		if (lengthOf(splitValue)>1) unitArray[i] = splitValue[1];
		else unitArray[i] = "";
		if (errorPos>0) unitArray[i] = "error"; // override with error if noted
		setResult("Parameter", i, parameterArray[i]);
		setResult("Value", i, valueArray[i]);
		setResult("unit", i, unitArray[i]);
	}
	excelPath = path + "_metadata.csv";
	if (File.exists(excelPath)==0) saveAs("Results", excelPath);
	else {
		overWriteFile=getBoolean("Do you want to overwrite " + excelPath + "?");
		if(overWriteFile==1)	saveAs("Results", excelPath);
	}
	run("Close");
	restoreResultsFrom("hiddenResults");
	setBatchMode("exit & display"); /* exit batch mode */
	/* 
	( 8(|)	( 8(|)	Functions	@@@@@:-)	@@@@@:-)
	*/
	function closeNonImageByTitle(windowTitle) { // obviously
	if (isOpen(windowTitle)) {
		selectWindow(windowTitle);
        run("Close");
		}
	}
	function hideResultsAs(deactivatedResults) {
		if (isOpen("Results")) {  /* This swapping of tables does not increase run time significantly */
			selectWindow("Results");
			IJ.renameResults(deactivatedResults);
		}
	}
	function restoreResultsFrom(deactivatedResults) {
		if (isOpen(deactivatedResults)) {
			selectWindow(deactivatedResults);		
			IJ.renameResults("Results");
		}
	}
	function saveExcelFile(outputDir, outputName, outputResultsTable) {
		selectWindow(outputResultsTable);
		resultsPath = outputDir + outputName + "_" + outputResultsTable + ".xls";
		if (File.exists(resultsPath)==0)
			saveAs("results", resultsPath);
		else {
			overWriteFile=getBoolean("Do you want to overwrite " + resultsPath + "?");
			if(overWriteFile==1)
					saveAs("results", resultsPath);
		}		
	}
}