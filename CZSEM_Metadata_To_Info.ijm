macro "Add Multiple Lines of SEM Metadata to ImageJ Info Header" {
	/* 	This macro adds multiple lines of SmartSEM metadata to the ImageJ info header
	This requires the tiff_tags plugin written by Joachim Wesner that can be downloaded from http://rsbweb.nih.gov/ij/plugins/tiff-tags.html
	Originally it was based on the scale extracting macro here: https://rsb.info.nih.gov/ij/macros/SetScaleFromTiffTag.txt but as usual things got a little out of hand . . . 
	Peter J. Lee Applied Superconductivity Center at National High Magnetic Field Laboratory
	Version v161105 */
	setBatchMode(true);
	dir = getDirectory("image");
	name = getInfo("image.filename");
	path = dir + name;
	if (path=="") path = getTitle();
	getPixelSize(unit, pixelWidth, pixelHeight);
	metaTagArray = ExtractZeissSEMmetadata();
	metaTagArray = Array.sort(metaTagArray);
	for (metaInfo = "", i = 0; i<metaTagArray.length; i++) {
		metaInfo += metaTagArray[i]+"\n";
		if (unit=="" || pixelWidth==1 || pixelHeight==1) {
			if (matches(metaTagArray[i], ".*Image Pixel Size =.*")) {
				splits = split(substring(metaTagArray[i], indexOf(metaTagArray[i], "=")+2));
				setVoxelSize(splits[0], splits[0], 1, splits[1]);
			}
		}
	}
	imagejInfo = getMetadata("Info");
	if (imagejInfo=="")  /* if Info tag is empty adds SEM metadata to imageJ info tag */
		setMetadata("Info", "SmartSEM Tags\nFor: " + path + "\n----------\n" + metaInfo);
	else if(lengthOf(imagejInfo)!=lengthOf(replace(imagejInfo,"SmartSEM",""))) exit("SmartSEM metadata already embedded");
	else {
		Dialog.create("Add to existing info label?");
			if(lengthOf(imagejInfo)>30) imagejInfoShort = substring(imagejInfo,0,30) + "...";
			else imagejInfoShort = imagejInfo;
			Dialog.addCheckbox("Add to existing info?: " + imagejInfoShort, true);
			Dialog.show;
			imagejInfoAdd = Dialog.getCheckbox;
		if (imagejInfoAdd)  /* Adds SEM metadata to end of existing imageJ info tag */
			setMetadata("Info", imagejInfo + "\n----------\nSmartSEM Tags\nFor: " + path + "\n----------\n" + metaInfo);
		else exit("Declined to add SmartSEM metadata to existing info header");
	}
	// print(getMetadata("Info")); /* For testing */
	setBatchMode("exit & display");
	showStatus("SmartSEM metadata import macro finished");
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