macro "Copy SmartSEM Metadata to ImageJ Info Header of Another Open Image" {
	/* 	This macro copies SmartSEM metadata from one image to the ImageJ info header of another open image
	This requires the tiff_tags plugin written by Joachim Wesner that can be downloaded from http://rsbweb.nih.gov/ij/plugins/tiff-tags.html
	Peter J. Lee Applied Superconductivity Center at National High Magnetic Field Laboratory
	Version v161106 */
	setBatchMode(true);
	t = getTitle();
	metaTagArray = ExtractZeissSEMmetadata();
	metaTagArray = Array.sort(metaTagArray);
	n = nImages;
    // windowIDList = newArray(n);
	windowNameList = newArray(n);
    for (i=1; i<=n; i++) {
        selectImage(i);
        // windowIDList[i-1] = getImageID();
		windowNameList[i-1] = getTitle();
    }
    setBatchMode(false); 
	Dialog.create("Select open image to transfer metadata to");
	Dialog.addChoice("Name", windowNameList);
	Dialog.show();
	selectWindow(Dialog.getChoice()); 
	imagejInfo = getMetadata("Info");
	monthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	dateString = "" + monthNames[month] + ":" + dayOfMonth + ":" + year;
	if (imagejInfo=="") {  /* if Info tag is empty adds SEM metadata to imageJ info tag */
		metaInfo = "\n----------\nSmartSEM Tags\nImported From:\n" + t + "\non " + dateString + "\n----------\n";
		for (i = 0; i<metaTagArray.length; i++)
			metaInfo += metaTagArray[i]+"\n";
		setMetadata("Info", metaInfo);
	}
	else if (lengthOf(imagejInfo)!=lengthOf(replace(imagejInfo,"SmartSEM",""))) exit("SmartSEM metadata already embedded");
	else {
		Dialog.create("Add to existing info label?");
			if(lengthOf(imagejInfo)>30) imagejInfoShort = substring(imagejInfo,0,30) + "...";
			else imagejInfoShort = imagejInfo;
			Dialog.addCheckbox("Add to existing info?: " + imagejInfoShort, true);
			Dialog.show;
			imagejInfoAdd = Dialog.getCheckbox;
		if (imagejInfoAdd) {  /* Adds SEM metadata to end of existing imageJ info tag */
			metaInfo = imagejInfo + "\n----------\nSmartSEM Tags\nImported From:\n" + t + "\non " + dateString + "\n----------\n";
			for (i = 0; i<metaTagArray.length; i++)
				metaInfo += metaTagArray[i]+"\n";
			setMetadata("Info", metaInfo);
		}
		else exit("Declined to add SmartSEM metadata to existing info header");
	}
	// print(getMetadata("Info")); /* For testing */
	setBatchMode("exit & display");
	showStatus("SmartSEM metadata copy macro finished");
/* 
	( 8(|)   ( 8(|)  Functions  ( 8(|)  ( 8(|)
*/
	function checkForPlugin(pluginName) {
		/* v161102 changed to true-false */
		var pluginCheck = false, subFolderCount = 0;
		if (getDirectory("plugins") == "") restoreExit("Failure to find any plugins!");
		else pluginDir = getDirectory("plugins");
		if (!endsWith(pluginName, ".jar")) pluginName = pluginName + ".jar";
		if (File.exists(pluginDir + pluginName)) {
				pluginCheck = true;
				showStatus(pluginName + "found in: "  + pluginDir);
		}
		else {
			pluginList = getFileList(pluginDir);
			subFolderList = newArray(pluginList.length);
			for (i=0; i<pluginList.length; i++) {
				if (endsWith(pluginList[i], "/")) {
					subFolderList[subFolderCount] = pluginList[i];
					subFolderCount = subFolderCount +1;
				}
			}
			subFolderList = Array.slice(subFolderList, 0, subFolderCount);
			for (i=0; i<subFolderList.length; i++) {
				if (File.exists(pluginDir + subFolderList[i] +  "\\" + pluginName)) {
					pluginCheck = true;
					showStatus(pluginName + " found in: " + pluginDir + subFolderList[i]);
					i = subFolderList.length;
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
 This version v161101 Peter J. Lee
*/
		dir = getDirectory("image");
		if (dir=="") exit ("path not available");
		name = getInfo("image.filename");
		if (name=="") exit ("name not available");
		if (!matches(getInfo("image.filename"),".*[tT][iI][fF].*")) exit("Not TIFF file");
		if (!checkForPlugin("tiff_tags.jar")) exit("Not TIFF file");
		path = dir + name;
		fullTag = call("TIFF_Tags.getTag", path, "34118");
		metaTagStart = indexOf(fullTag, "DP_ZOOM");
		if (metaTagStart<0) metaArray = newArray("false");
		else {
			tag = substring(fullTag, metaTagStart);
			for (i=0; i<10; i++) tag = replace(tag, "  ", " ");
			tag = replace(tag, "DP_", "|DP_");
			tag = replace(tag, "AP_", "|AP_");
			tag = replace(tag, "SV_", "|SV_");
			metaArray = split(tag, "|");
			for (i=0; i<metaArray.length; i++)
				metaArray[i] = substring(metaArray[i], indexOf(metaArray[i], " ")+1);
		}
		return metaArray;
	}
}