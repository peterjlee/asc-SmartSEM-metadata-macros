macro "Copy SmartSEM Metadata to ImageJ Info Header of Another Open Image" {
	/* 	This macro copies SmartSEM metadata from one image to the ImageJ info header of another open image
	This requires the tiff_tags plugin written by Joachim Wesner that can be downloaded from http://rsbweb.nih.gov/ij/plugins/tiff-tags.html
	Peter J. Lee Applied Superconductivity Center at National High Magnetic Field Laboratory
	Version v180215-f1 function updates 5/16/2022 12:52 PM and f2: 8/18/2022 1:43 PM  f3 (053023) updated ExtractZeissSEMmetadata function to warn of header length overrun */
	macroL = "CZSEM_Metadata_to_Info_v180215-f3.ijm";
	setBatchMode(true);
	t = getTitle();
	metaTagArray = ExtractZeissSEMmetadata();
	metaTagArray = Array.sort(metaTagArray);
	n = nImages;
	windowNameList = newArray(n);
    for (i=1; i<=n; i++) {
        selectImage(i);
		windowNameList[i-1] = getTitle();
    }
    setBatchMode(false); 
	Dialog.create("Select open image to transfer metadata to \(" + macroL + "\)");
	Dialog.addChoice("Name", windowNameList);
	Dialog.show();
	selectWindow(Dialog.getChoice()); 
	imagejInfo = getMetadata("Info");
	monthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	dateString = "" + monthNames[month] + ":" + dayOfMonth + ":" + year;
	if (imagejInfo=="") {  /* if Info tag is empty adds SEM metadata to imageJ info tag */
		metaInfo = "\n----------\nSmartSEM Tags\nImported From:\n" + t + "\non " + dateString + "\n----------\n";
		for (i = 0; i<lengthOf(metaTagArray); i++)
			metaInfo += metaTagArray[i]+"\n";
		setMetadata("Info", metaInfo);
	}
	else if (lengthOf(imagejInfo)!=lengthOf(replace(imagejInfo,"SmartSEM",""))) exit("SmartSEM metadata already embedded");
	else {
		Dialog.create("Add to existing info label? \(" + macroL + "\)");
			if(lengthOf(imagejInfo)>30) imagejInfoShort = substring(imagejInfo,0,30) + "...";
			else imagejInfoShort = imagejInfo;
			Dialog.addCheckbox("Add to existing info?: " + imagejInfoShort, true);
			Dialog.show;
			imagejInfoAdd = Dialog.getCheckbox;
		if (imagejInfoAdd) {  /* Adds SEM metadata to end of existing imageJ info tag */
			metaInfo = imagejInfo + "\n----------\nSmartSEM Tags\nImported From:\n" + t + "\non " + dateString + "\n----------\n";
			for (i = 0; i<lengthOf(metaTagArray); i++)
				metaInfo += metaTagArray[i]+"\n";
			setMetadata("Info", metaInfo);
		}
		else exit("Declined to add SmartSEM metadata to existing info header");
	}
	// print(getMetadata("Info")); /* For testing */
	setBatchMode("exit & display");
	showStatus("SmartSEM metadata copy macro finished");
}
/* 
	( 8(|)   ( 8(|)  Functions  ( 8(|)  ( 8(|)
*/
	function checkForPlugin(pluginName) {
		/* v161102 changed to true-false
			v180831 some cleanup
			v210429 Expandable array version
			v220510 Looks for both class and jar if no extension is given
			v220818 Mystery issue fixed, no longer requires restoreExit	*/
		pluginCheck = false;
		if (getDirectory("plugins") == "") print("Failure to find any plugins!");
		else {
			pluginDir = getDirectory("plugins");
			if (lastIndexOf(pluginName,".")==pluginName.length-1) pluginName = substring(pluginName,0,pluginName.length-1);
			pExts = newArray(".jar",".class");
			knownExt = false;
			for (j=0; j<lengthOf(pExts); j++) if(endsWith(pluginName,pExts[j])) knownExt = true;
			pluginNameO = pluginName;
			for (j=0; j<lengthOf(pExts) && !pluginCheck; j++){
				if (!knownExt) pluginName = pluginName + pExts[j];
				if (File.exists(pluginDir + pluginName)) {
					pluginCheck = true;
					showStatus(pluginName + "found in: "  + pluginDir);
				}
				else {
					pluginList = getFileList(pluginDir);
					subFolderList = newArray;
					for (i=0,subFolderCount=0; i<lengthOf(pluginList); i++) {
						if (endsWith(pluginList[i], "/")) {
							subFolderList[subFolderCount] = pluginList[i];
							subFolderCount++;
						}
					}
					for (i=0; i<lengthOf(subFolderList); i++) {
						if (File.exists(pluginDir + subFolderList[i] +  "\\" + pluginName)) {
							pluginCheck = true;
							showStatus(pluginName + " found in: " + pluginDir + subFolderList[i]);
							i = lengthOf(subFolderList);
						}
					}
				}
			}
		}
		return pluginCheck;
	}
	function ExtractZeissSEMmetadata() {
	/* This macro extracts the metadata from the TIFF file header of an Zeiss SEM image.
 it is based on the scale extracting macro here: https://rsb.info.nih.gov/ij/macros/SetScaleFromTiffTag.txt
 This requires the tiff_tags plugin written by Joachim Wesner that can be downloaded from http://rsbweb.nih.gov/ij/plugins/tiff-tags.html
 There is an example image available at http://rsbweb.nih.gov/ij/images/SmartSEMSample.tif
 See also the original Nabble post by Pablo Manuel Jais: http://imagej.1557.x6.nabble.com/Importing-SEM-images-with-scale-td3689900.html This version: https://rsb.info.nih.gov/ij/macros/SetScaleFromTiffTag.txt
 v161101 Peter J. Lee
 v220624: This version added warning of file overrun to array.
*/
		dir = getDirectory("image");
		if (dir=="") exit ("path not available");
		name = getInfo("image.filename");
		if (name=="") exit ("name not available");
		if (!matches(getInfo("image.filename"),".*[tT][iI][fF].*")) exit("Not a TIFF file \(original Zeiss TIFF file required\)");
		path = dir + name;
		if (checkForPlugin("tiff_tags.jar"))	fullTag = call("TIFF_Tags.getTag", path, "34118");
		else exit("Not a Zeiss TIFF file \(original Zeiss TIFF file required\)");
		metaTagStart = indexOf(fullTag, "DP_");
		if (metaTagStart<0) metaArray = newArray("false");
		else {
			tag = substring(fullTag, metaTagStart);
			for (i=0; i<10; i++) tag = replace(tag, "  ", " ");
			tag = replace(tag, "DP_", "|DP_");
			tag = replace(tag, "AP_", "|AP_");
			tag = replace(tag, "SV_", "|SV_");
			metaArray = split(tag, "|");
			for (i=0; i<lengthOf(metaArray); i++)
				metaArray[i] = substring(metaArray[i], indexOf(metaArray[i], " ")+1);
		}
		if (lengthOf(fullTag)>=32767) metaArray = Array.concat("Header length exceeds max",metaArray);
		return metaArray;
	}