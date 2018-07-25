/* 
	This macro adds multiple operating parameters extracted from SmartSEM metadata to a copy of the image.
	This requires the tiff_tags plugin written by Joachim Wesner that can be downloaded from http://rsbweb.nih.gov/ij/plugins/tiff-tags.html
	Originally it was based on the scale extracting macro here: https://rsb.info.nih.gov/ij/macros/SetScaleFromTiffTag.txt but as usual things got a little out of hand . . . 
	Peter J. Lee Applied Superconductivity Center at National High Magnetic Field Laboratory.
	Version v170411 removes spaces in image names to fix issue with new image combinations.
	v180725 Adds system fonts to font list.
 */
macro "Add Multiple Lines of SEM Metadata to Image" {
	/* We will assume you are using an up to date imageJ */
	saveSettings;
	setBatchMode(true);
	if (selectionType>=0) {
		selEType = selectionType; 
		selectionExists = 1;
		getSelectionBounds(selEX, selEY, selEWidth, selEHeight);
	}
	else selectionExists = 0;
	t=getTitle();
	// Checks to see if a Ramp legend rather than the image has been selected by accident
	if (matches(t, ".*Ramp.*")==1) showMessageWithCancel("Title contains \"Ramp\"", "Do you want to label" + t + " ?"); 
	metaTagArray = ExtractZeissSEMmetadata();
	metaTagArray = Array.sort(metaTagArray);
	imagejInfo = getMetadata("Info");
	if (imagejInfo=="") {  /* if Info tag is empty adds SEM metadata to imageJ info tag */
		metaInfo = "SmartSEM Tags\n----------\n";
		for (i = 0; i<lengthOf(metaTagArray); i++)
			metaInfo += metaTagArray[i]+"\n";
		setMetadata("Info", metaInfo);
	}
	else if (lengthOf(imagejInfo)==lengthOf(replace(imagejInfo,"SmartSEM",""))){	
		Dialog.create("Add SmartSEM metadata to existing non-SmartSEM imageJ info tag?");
			if(lengthOf(imagejInfo)>30) imagejInfoShort = substring(imagejInfo,0,30) + "...";
			else imagejInfoShort = imagejInfo;
			Dialog.addCheckbox("Add to existing info?: " + imagejInfoShort, true);
			Dialog.show;
			imagejInfoAdd = Dialog.getCheckbox;
		if (imagejInfoAdd) {  /* Adds SEM metadata to end of existing imageJ info tag */
			metaInfo = imagejInfo + "\n----------\nSmartSEM Tags\n----------\n";
			for (i = 0; i<lengthOf(metaTagArray); i++)
				metaInfo += metaTagArray[i]+"\n";
			setMetadata("Info", metaInfo);
		}
	}
	// print(getMetadata("Info")); /* For testing purposes */
	favoriteParameters = newArray("Aperture Size =", "Brightness =", "Contrast =", "EHT =", "WD =", "Date :", "Time :", "Height =", "Width =", "Image Pixel Size =", "Mag =", "Signal A =", "Noise Reduction =",  "Scan Speed =", "Cycle Time =", "Line Time =", "N", "Line Avg.Count", "Stage at T =", "Tilt Angle =", "Tilt Corrn. =", "Scan Rotation =", "Stage Angle =", "Stage at X =", "Stage at Y =",  "Stage at Z =", "User Name =", "File Name =");  /* not used: , "Sample ID ="  */
	textChoiceLines = lengthOf(favoriteParameters); /* Number of optional lines */
	if (lengthOf(metaTagArray)<(213+textChoiceLines)) restoreExit("Header appears to be non-standard"); 
	for (i = 0; i<lengthOf(favoriteParameters); i++) {
		for (j = 0; j<lengthOf(metaTagArray); j++) {
			if(matches(metaTagArray[j], favoriteParameters[i]+".*"))
				favoriteParameters[i] = metaTagArray[j];
		} 
	}
	alternativeChoices = newArray("-none-", "-blank-", "-user input-");
	textChoices = Array.concat(alternativeChoices, favoriteParameters, alternativeChoices, metaTagArray);
	textChoiceLines = textChoiceLines-2;
	imageWidth = getWidth();
	imageHeight = getHeight();
	imageDims = imageHeight + imageWidth;
	originalImageDepth = bitDepth();
	id = getImageID();
	fontSize = round(imageDims/140); /* default font size is small for this variant */
	if (fontSize < 10) fontSize = 10; /* set minimum default font size as 12 */
	lineSpacing = 1.1;
	outlineStroke = 8; /* default outline stroke: % of font size */
	shadowDrop = 12;  /* default outer shadow drop: % of font size */
	dIShO = 5; /* default inner shadow drop: % of font size */
	shadowDisp = shadowDrop;
	shadowBlur = 1.1* shadowDrop;
	shadowDarkness = 60;
	innerShadowDrop = dIShO;
	innerShadowDisp = dIShO;
	innerShadowBlur = floor(dIShO/2);
	innerShadowDarkness = 20;
	selOffsetX = round(1 + imageWidth/150); /* default offset of label from edge */
	selOffsetY = round(1 + imageHeight/150); /* default offset of label from edge */
	/* Then Dialog . . . */
	Dialog.create("Basic Label Options");
		if (selectionExists==1) {
			textLocChoices = newArray("Top Left", "Top Right", "Center", "Bottom Left", "Bottom Right", "Center of New Selection", "At Selection"); 
			loc = 6;
		} else {
			textLocChoices = newArray("Top Left", "Top Right", "Center", "Bottom Left", "Bottom Right", "Center of New Selection"); 
			loc = 0;
		}
		Dialog.addChoice("Location:", textLocChoices, textLocChoices[loc]);
		if (selectionExists==1) {
			Dialog.addNumber("Selection Bounds: X start = ", selEX);
			Dialog.addNumber("Selection Bounds: Y start = ", selEY);
			Dialog.addNumber("Selection Bounds: Width = ", selEWidth);
			Dialog.addNumber("Selection Bounds: Height = ", selEHeight);
		}
		Dialog.addNumber("Font size & color:", fontSize, 0, 3,"");
		if (originalImageDepth==24)
			colorChoice = newArray("white", "black", "light_gray", "gray", "dark_gray", "red", "pink", "green", "blue", "yellow", "orange", "garnet", "gold", "aqua_modern", "blue_accent_modern", "blue_dark_modern", "blue_modern", "gray_modern", "green_dark_modern", "green_modern", "orange_modern", "pink_modern", "purple_modern", "red_N_modern", "red_modern", "tan_modern", "violet_modern", "yellow_modern"); 
		else colorChoice = newArray("white", "black", "light_gray", "gray", "dark_gray");
		Dialog.setInsets(-30, 60, 0);
		Dialog.addChoice("Text color:", colorChoice, colorChoice[0]);
		fontStyleChoice = newArray("bold", "bold antialiased", "italic", "italic antialiased", "bold italic", "bold italic antialiased", "unstyled");
		Dialog.addChoice("Font style:", fontStyleChoice, fontStyleChoice[1]);
		fontNameChoice = getFontChoiceList();
		Dialog.addChoice("Font name:", fontNameChoice, fontNameChoice[0]);
		Dialog.addChoice("Outline color:", colorChoice, colorChoice[1]);
		Dialog.setInsets(-60, 420, 0);
		Dialog.addMessage("Labels: ^2 & um etc. replaced by " + fromCharCode(178) + " & " + fromCharCode(181) + "m etc. If \nthe units are in the nparameter label, within \(...\) \ni.e. \(unit\) they will override this selection:");
		for (i=0; i<textChoiceLines; i++)
			Dialog.addChoice("Line "+(i+1)+":", textChoices, textChoices[i+3]);
		Dialog.addChoice("Tweak the Formatting? ", newArray("Yes", "No"), "No");
		Dialog.setInsets(-30, 250, 0);
		Dialog.addMessage("Pull down for more options: User-input, blank lines and ALL other parameters");
/*	*/
		Dialog.show();
		textLocChoice = Dialog.getChoice();
		if (selectionExists==1) {
			selEX =  Dialog.getNumber();
			selEY =  Dialog.getNumber();
			selEWidth =  Dialog.getNumber();
			selEHeight =  Dialog.getNumber();
		}
		fontSize =  Dialog.getNumber();
		selColor = Dialog.getChoice();
		fontStyle = Dialog.getChoice();
		fontName = Dialog.getChoice();
		outlineColor = Dialog.getChoice();
		textInputLines = newArray(textChoiceLines);
		for (i=0; i<textChoiceLines; i++)
			textInputLines[i] = Dialog.getChoice();
		tweakFormat = Dialog.getChoice();
/*	*/
	if (tweakFormat=="Yes") {	
		Dialog.create("Advanced Formatting Options");
		Dialog.addNumber("X Offset from Edge in Pixels \(applies to corners only\)", selOffsetX,0,1,"pixels");
		Dialog.addNumber("Y Offset from Edge in Pixels \(applies to corners only\)", selOffsetY,0,1,"pixels");
		Dialog.addNumber("Line Spacing", lineSpacing,0,3,"");
		Dialog.addNumber("Outline Stroke:", outlineStroke,0,3,"% of font size");
		Dialog.addChoice("Outline (background) color:", colorChoice, colorChoice[1]);
		Dialog.addNumber("Shadow Drop: ±", shadowDrop,0,3,"% of font size");
		Dialog.addNumber("Shadow Displacement Right: ±", shadowDrop,0,3,"% of font size");
		Dialog.addNumber("Shadow Gaussian Blur:", floor(0.75 * shadowDrop),0,3,"% of font size");
		Dialog.addNumber("Shadow Darkness:", 75,0,3,"%\(darkest = 100%\)");
		// Dialog.addMessage("The following \"Inner Shadow\" options do not change the Overlay Labels");
		Dialog.addNumber("Inner Shadow Drop: ±", dIShO,0,3,"% of font size");
		Dialog.addNumber("Inner Displacement Right: ±", dIShO,0,3,"% of font size");
		Dialog.addNumber("Inner Shadow Mean Blur:",floor(dIShO/2),1,3,"% of font size");
		Dialog.addNumber("Inner Shadow Darkness:", 20,0,3,"% \(darkest = 100%\)");
	
		Dialog.show();
		selOffsetX = Dialog.getNumber();
		selOffsetY = Dialog.getNumber();
		lineSpacing = Dialog.getNumber();
		outlineStroke = Dialog.getNumber();
		outlineColor = Dialog.getChoice();
		shadowDrop = Dialog.getNumber();
		shadowDisp = Dialog.getNumber();
		shadowBlur = Dialog.getNumber();
		shadowDarkness = Dialog.getNumber();
		innerShadowDrop = Dialog.getNumber();
		innerShadowDisp = Dialog.getNumber();
		innerShadowBlur = Dialog.getNumber();
		innerShadowDarkness = Dialog.getNumber();
	}
	
	negAdj = 0.5;  /* negative offsets appear exaggerated at full displacement */
	if (shadowDrop<0) shadowDrop *= negAdj;
	if (shadowDisp<0) shadowDisp *= negAdj;
	if (shadowBlur<0) shadowBlur *= negAdj;
	if (innerShadowDrop<0) innerShadowDrop *= negAdj;
	if (innerShadowDisp<0) innerShadowDisp *= negAdj;
	if (innerShadowBlur<0) innerShadowBlur *= negAdj;
	
	fontFactor = fontSize/100;
	outlineStroke = floor(fontFactor * outlineStroke);
	shadowDrop = floor(fontFactor * shadowDrop);
	shadowDisp = floor(fontFactor * shadowDisp);
	shadowBlur = floor(fontFactor * shadowBlur);
	innerShadowDrop = floor(fontFactor * innerShadowDrop);
	innerShadowDisp = floor(fontFactor * innerShadowDisp);
	innerShadowBlur = floor(fontFactor * innerShadowBlur);
	
	if (fontStyle=="unstyled") fontStyle="";
			
	textOutNumber = 0;
	textInputLinesText = newArray(textChoiceLines);
	setFont(fontName, fontSize, fontStyle);
	longestStringWidth = 0;
	for (i=0; i<textChoiceLines; i++) {
		if(textInputLines[i]=="-none-") i = i+1;
		else if (textInputLines[i]!="-blank-") {
			if (textInputLines[i]=="-user input-") {
				Dialog.create("Basic Label Options");
				Dialog.addString("Label Line "+(i+1)+":","", 30);
				Dialog.show();
				textInputLines[i] = Dialog.getString();
			}
			textInputLinesText[i] = "" + cleanLabel(textInputLines[i]);
			textOutNumber = i+1;
			if (getStringWidth(textInputLinesText[i])>longestStringWidth) longestStringWidth = getStringWidth(textInputLines[i]);
		}
	}
	linesSpace = lineSpacing * (textOutNumber-1) * fontSize;
		if (textLocChoice == "Top Left") {
		selEX = selOffsetX;
		selEY = selOffsetY;
	} else if (textLocChoice == "Top Right") {
		selEX = imageWidth - longestStringWidth - selOffsetX;
		selEY = selOffsetY;
	} else if (textLocChoice == "Center") {
		selEX = round((imageWidth - longestStringWidth)/2);
		selEY = round((imageHeight - linesSpace)/2);
	} else if (textLocChoice == "Bottom Left") {
		selEX = selOffsetX;
		selEY = imageHeight - (selOffsetY + linesSpace); 
	} else if (textLocChoice == "Bottom Right") {
		selEX = imageWidth - longestStringWidth - selOffsetX;
		selEY = imageHeight - (selOffsetY + linesSpace);
	} else if (textLocChoice == "Center of New Selection"){
		setTool("rectangle");
		if (is("Batch Mode")==true) setBatchMode(false); /* Does not accept interaction while batch mode is on */
		msgtitle="Location for the text labels...";
		msg = "Draw a box in the image where you want to center the text labels...";
		waitForUser(msgtitle, msg);
		getSelectionBounds(newSelEX, newSelEY, newSelEWidth, newSelEHeight);
		selEX = newSelEX + round((newSelEWidth/2) - longestStringWidth/1.5);
		selEY = newSelEY + round((newSelEHeight/2) - (linesSpace/2));
		if (is("Batch Mode")==false) setBatchMode(true);	/* toggle batch mode back on */
	} else if (selectionExists==1) {
		selEX = selEX + round((selEWidth/2) - longestStringWidth/1.5);
		selEY = selEY + round((selEHeight/2) - (linesSpace/2));
	}
	run("Select None");
	if (selEY<=1.5*fontSize)
		selEY += fontSize;
	if (selEX<selOffsetX) selEX = selOffsetX;
	endX = selEX + longestStringWidth;
	if ((endX+selOffsetX)>imageWidth) selEX = imageWidth - longestStringWidth - selOffsetX;
	textLabelX = selEX;
	textLabelY = selEY;
	setColorFromColorName("white");
	setBatchMode(true);
	roiManager("show none");
	// run("Flatten"); /* changes bit depth */
	run("Duplicate...", t+"+text");
	labeledImage = getTitle();
	// if (is("Batch Mode")==false) setBatchMode(true);
	newImage("label_mask", "8-bit black", imageWidth, imageHeight, 1);
	roiManager("deselect");
	run("Select None");
	/* Draw summary over top of labels */
	setFont(fontName,fontSize, fontStyle);
	for (i=0; i<textOutNumber; i++) {
		// if (textInputLines[i]!="None") textOutNumber = textOutNumber + 1;
		if (textInputLines[i]!="-blank-") {
			drawString(textInputLinesText[i], textLabelX, textLabelY);
			textLabelY += lineSpacing * fontSize;
		}
		else textLabelY += lineSpacing * fontSize;
	}
	setThreshold(0, 128);
	setOption("BlackBackground", false);
	run("Convert to Mask");
	/* Create drop shadow if desired */
	if (shadowDrop!=0 || shadowDisp!=0 || shadowBlur!=0)
		createShadowDropFromMask();
	// setBatchMode("exit & display");
	/* Create inner shadow if desired */
	if (innerShadowDrop!=0 || innerShadowDisp!=0 || innerShadowBlur!=0)
		createInnerShadowFromMask();
	if (isOpen("shadow") && shadowDarkness>0)
		imageCalculator("Subtract", labeledImage,"shadow");
	if (isOpen("shadow") && shadowDarkness<0)
		imageCalculator("Subtract", labeledImage,"shadow"); /* glow */
	run("Select None");
	getSelectionFromMask("label_mask");
	run("Enlarge...", "enlarge=[outlineStroke] pixel");
	setBackgroundFromColorName(outlineColor);
	run("Clear");
	run("Select None");
	getSelectionFromMask("label_mask");
	setBackgroundFromColorName(selColor);
	run("Clear");
	run("Select None");
	if (isOpen("inner_shadow")) imageCalculator("Subtract", labeledImage,"inner_shadow");
	closeImageByTitle("shadow");
	closeImageByTitle("inner_shadow");
	closeImageByTitle("label_mask");
	selectWindow(labeledImage);
	/* now rename image to reflect changes and avoid danger of overwriting original */
	if ((lastIndexOf(t,"."))>0)  labeledImageNameWOExt = unCleanLabel(substring(labeledImage, 0, lastIndexOf(labeledImage,".")));
	else labeledImageNameWOExt = unCleanLabel(labeledImage);
	rename(labeledImageNameWOExt + "+SmartSEM Annotation");
	setBatchMode("exit & display");
	showStatus("Fancy SmartSEM annotation macro finished");
/* 
	( 8(|)	( 8(|)	Functions	@@@@@:-)	@@@@@:-)
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
			subFolderList = newArray(lengthOf(pluginList));
			for (i=0; i<lengthOf(pluginList); i++) {
				if (endsWith(pluginList[i], "/")) {
					subFolderList[subFolderCount] = pluginList[i];
					subFolderCount = subFolderCount +1;
				}
			}
			subFolderList = Array.slice(subFolderList, 0, subFolderCount);
			for (i=0; i<lengthOf(subFolderList); i++) {
				if (File.exists(pluginDir + subFolderList[i] +  "\\" + pluginName)) {
					pluginCheck = true;
					showStatus(pluginName + " found in: " + pluginDir + subFolderList[i]);
					i = lengthOf(subFolderList);
				}
			}
		}
		return pluginCheck;
	}
	function cleanLabel(string) {
		/* v161104 */
		string= replace(string, "\\^2", fromCharCode(178)); /* superscript 2 */
		string= replace(string, "\\^3", fromCharCode(179)); /* superscript 3 UTF-16 (decimal) */
		string= replace(string, "\\^-1", fromCharCode(0x207B) + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-2", fromCharCode(0x207B) + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-^1", fromCharCode(0x207B) + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-^2", fromCharCode(0x207B) + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "(?<![A-Za-z0-9])u(?=m)", fromCharCode(181)); /* micron units */
		string= replace(string, "\\b[aA]ngstrom\\b", fromCharCode(197)); /* Ångström unit symbol */
		string= replace(string, "  ", " "); /* Replace double spaces with single spaces */
		string= replace(string, "_", fromCharCode(0x2009)); /* Replace underlines with thin spaces */
		string= replace(string, "px", "pixels"); /* Expand pixel abbreviation */
		string = replace(string, " " + fromCharCode(0x00B0), fromCharCode(0x00B0)); /* Remove space before degree symbol */
		string= replace(string, " °", fromCharCode(0x2009)+"°"); /* Remove space before degree symbol */
		string= replace(string, "sigma", fromCharCode(0x03C3)); /* sigma for tight spaces */
		return string;
	}
	function closeImageByTitle(windowTitle) {  /* Cannot be used with tables */
        if (isOpen(windowTitle)) {
		selectWindow(windowTitle);
        close();
		}
	}
	function createInnerShadowFromMask() {
		/* Requires previous run of: originalImageDepth = bitDepth();
		because this version works with different bitDepths
		v161104 */
		showStatus("Creating inner shadow for labels . . . ");
		newImage("inner_shadow", "8-bit white", imageWidth, imageHeight, 1);
		getSelectionFromMask("label_mask");
		setBackgroundColor(0,0,0);
		run("Clear Outside");
		getSelectionBounds(selMaskX, selMaskY, selMaskWidth, selMaskHeight);
		setSelectionLocation(selMaskX-innerShadowDisp, selMaskY-innerShadowDrop);
		setBackgroundColor(0,0,0);
		run("Clear Outside");
		getSelectionFromMask("label_mask");
		expansion = abs(innerShadowDisp) + abs(innerShadowDrop) + abs(innerShadowBlur);
		if (expansion>0) run("Enlarge...", "enlarge=[expansion] pixel");
		if (innerShadowBlur>0) run("Gaussian Blur...", "sigma=[innerShadowBlur]");
		run("Unsharp Mask...", "radius=0.5 mask=0.2"); /* A tweak to sharpen the effect for small font sizes */
		imageCalculator("Max", "inner_shadow","label_mask");
		run("Select None");
		/* The following are needed for different bit depths */
		if (originalImageDepth==16 || originalImageDepth==32) run(originalImageDepth + "-bit");
		run("Enhance Contrast...", "saturated=0 normalize");
		run("Invert");  /* Create an image that can be subtracted - this works better for color than Min */
		divider = (100 / abs(innerShadowDarkness));
		run("Divide...", "value=[divider]");
	}
	function createShadowDropFromMask() {
		/* Requires previous run of: originalImageDepth = bitDepth();
		because this version works with different bitDepths
		v161104 */
		showStatus("Creating drop shadow for labels . . . ");
		newImage("shadow", "8-bit black", imageWidth, imageHeight, 1);
		getSelectionFromMask("label_mask");
		getSelectionBounds(selMaskX, selMaskY, selMaskWidth, selMaskHeight);
		setSelectionLocation(selMaskX+shadowDisp, selMaskY+shadowDrop);
		setBackgroundColor(255,255,255);
		if (outlineStroke>0) run("Enlarge...", "enlarge=[outlineStroke] pixel"); /* Adjust shadow size so that shadow extends beyond stroke thickness */
		run("Clear");
		run("Select None");
		if (shadowBlur>0) {
			run("Gaussian Blur...", "sigma=[shadowBlur]");
			// run("Unsharp Mask...", "radius=[shadowBlur] mask=0.4"); // Make Gaussian shadow edge a little less fuzzy
		}
		/* Now make sure shadow or glow does not impact outline */
		getSelectionFromMask("label_mask");
		if (outlineStroke>0) run("Enlarge...", "enlarge=[outlineStroke] pixel");
		setBackgroundColor(0,0,0);
		run("Clear");
		run("Select None");
		/* The following are needed for different bit depths */
		if (originalImageDepth==16 || originalImageDepth==32) run(originalImageDepth + "-bit");
		run("Enhance Contrast...", "saturated=0 normalize");
		divider = (100 / abs(shadowDarkness));
		run("Divide...", "value=[divider]");
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
		if (!matches(getInfo("image.filename"),".*[tT][iI][fF].*")) exit("Not a TIFF file \(original Zeiss TIFF file required\)");
		if (!checkForPlugin("tiff_tags.jar")) exit("Not a TIFF file \(original Zeiss TIFF file required\)");
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
			for (i=0; i<lengthOf(metaArray); i++)
				metaArray[i] = substring(metaArray[i], indexOf(metaArray[i], " ")+1);
		}
		return metaArray;
	}
	function ExtractZeissSEMParametersFromMetadata(metaArray) {
		parameterTempArray = newArray(lengthOf(metaArray));
		for (i=0; i<lengthOf(metaArray); i++) {
			if (matches(metaArray[i], ".*=.*")) parameterTempArray[i] = substring(metaArray[i], 0, indexOf(metaArray[i], "=")-1);
			else if (matches(metaArray[i], ".* :.*")) parameterTempArray[i] = substring(metaArray[i], 0, indexOf(metaArray[i], " :"));
			else if (matches(metaArray[i], ".*error.*")) parameterTempArray[i] = substring(metaArray[i], 0, indexOf(metaArray[i], "error")-1);
			else parameterTempArray[i] = "parsing_error";
		}return parameterTempArray;
	}
	function ExtractZeissSEMValuesFromMetadata(metaArray) {
		valueTempArray = newArray(lengthOf(metaArray));
		for (i=0; i<lengthOf(metaArray); i++) {
			if (matches(metaArray[i], ".*=.*")) valueTempArray[i] = substring(metaArray[i], indexOf(metaArray[i], "=")+2);
			else if (matches(metaArray[i], ".* :.*")) valueTempArray[i] = substring(metaArray[i], indexOf(metaArray[i], " :")+2);
			else if (matches(metaArray[i], ".*error.*")) valueTempArray[i] = substring(metaArray[i], indexOf(metaArray[i], "error"));
			else valueTempArray[i] = "parsing_error";
			splits = split(valueTempArray[i]);
			if (lengthOf(splits)>0) valueTempArray[i] = splits[0];
			else valueTempArray[i] = "";
		}return valueTempArray;
	}
	function ExtractZeissSEMUnitsFromMetadata(metaArray) {
		unitsTempArray = newArray(lengthOf(metaArray));
		for (i=0; i<lengthOf(metaArray); i++) {
			if (matches(metaArray[i], ".*=.*")) unitsTempArray[i] = substring(metaArray[i], indexOf(metaArray[i], "=")+2);
			else if(matches(metaArray[i], ".* :.*")) unitsTempArray[i] = substring(metaArray[i], indexOf(metaArray[i], " :")+2);
			else if (matches(metaArray[i], ".*error.*")) unitsTempArray[i] = substring(metaArray[i], indexOf(metaArray[i], "error"));
			else unitsTempArray[i] = "parsing_error";
			splits = split(unitsTempArray[i]);
			if (lengthOf(splits)<=1) unitsTempArray[i] = "";
			else if (lengthOf(splits)==2) unitsTempArray[i] = splits[1];
			else unitsTempArray[i] = splits[1]+ " " + splits[2]; /* Needed for date */
		}return unitsTempArray;
	}
	
	/*	Color Functions	*/
	
	function getColorArrayFromColorName(colorName) {
		cA = newArray(255,255,255);
		if (colorName == "white") cA = newArray(255,255,255);
		else if (colorName == "black") cA = newArray(0,0,0);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "red") cA = newArray(255,0,0);
		else if (colorName == "pink") cA = newArray(255, 192, 203);
		else if (colorName == "green") cA = newArray(0,255,0);
		else if (colorName == "blue") cA = newArray(0,0,255);
		else if (colorName == "yellow") cA = newArray(255,255,0);
		else if (colorName == "orange") cA = newArray(255, 165, 0);
		else if (colorName == "garnet") cA = newArray(120,47,64);
		else if (colorName == "gold") cA = newArray(206,184,136);
		else if (colorName == "aqua_modern") cA = newArray(75,172,198);
		else if (colorName == "blue_accent_modern") cA = newArray(79,129,189);
		else if (colorName == "blue_dark_modern") cA = newArray(31,73,125);
		else if (colorName == "blue_modern") cA = newArray(58,93,174);
		else if (colorName == "gray_modern") cA = newArray(83,86,90);
		else if (colorName == "green_dark_modern") cA = newArray(121,133,65);
		else if (colorName == "green_modern") cA = newArray(155,187,89);
		else if (colorName == "orange_modern") cA = newArray(247,150,70);
		else if (colorName == "pink_modern") cA = newArray(255,105,180);
		else if (colorName == "purple_modern") cA = newArray(128,100,162);
		else if (colorName == "red_N_modern") cA = newArray(227,24,55);
		else if (colorName == "red_modern") cA = newArray(192,80,77);
		else if (colorName == "tan_modern") cA = newArray(238,236,225);
		else if (colorName == "violet_modern") cA = newArray(76,65,132);
		else if (colorName == "yellow_modern") cA = newArray(247,238,69);
		return cA;
	}
	function setColorFromColorName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	function setBackgroundFromColorName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setBackgroundColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	function getHexColorFromRGBArray(colorNameString) {
		colorArray = getColorArrayFromColorName(colorNameString);
		 r = toHex(colorArray[0]); g = toHex(colorArray[1]); b = toHex(colorArray[2]);
		 hexName= "#" + ""+pad(r) + ""+pad(g) + ""+pad(b);
		 return hexName;
	}
	function pad(n) {
		n= toString(n); if (lengthOf(n)==1) n= "0"+n; return n;
	}
		
	/*	End of Color Functions	*/
	
	function getFontChoiceList() {
		/* v180723 first version */
		systemFonts = getFontList();
		IJFonts = newArray("SansSerif", "Serif", "Monospaced");
		fontNameChoice = Array.concat(IJFonts,systemFonts);
		faveFontList = newArray("Your favorite fonts here", "SansSerif", "Arial Black", "Open Sans ExtraBold", "Calibri", "Roboto", "Roboto Bk", "Tahoma", "Times New Roman", "Helvetica");
		faveFontListCheck = newArray(faveFontList.length);
		counter = 0;
		for (i=0; i<faveFontList.length; i++) {
			for (j=0; j<fontNameChoice.length; j++) {
				if (faveFontList[i] == fontNameChoice[j]) {
					faveFontListCheck[counter] = faveFontList[i];
					counter +=1;
					j = fontNameChoice.length;
				}
			}
		}
		faveFontListCheck = Array.trim(faveFontListCheck, counter);
		fontNameChoice = Array.concat(faveFontListCheck,fontNameChoice);
		return fontNameChoice;
	}	
	function getSelectionFromMask(selection_Mask){
		batchMode = is("Batch Mode"); /* Store batch status mode before toggling */
		if (!batchMode) setBatchMode(true); /* Toggle batch mode on if previously off */
		tempTitle = getTitle();
		selectWindow(selection_Mask);
		run("Create Selection"); /* Selection inverted perhaps because the mask has an inverted LUT? */
		run("Make Inverse");
		selectWindow(tempTitle);
		run("Restore Selection");
		if (!batchMode) setBatchMode(false); /* Return to original batch mode setting */
	}
	function restoreResultsFrom(deactivatedResults) {
		if (isOpen(deactivatedResults)) {
			selectWindow(deactivatedResults);		
			IJ.renameResults("Results");
		}
	}
	function unCleanLabel(string) { 
	/* v161104 This function replaces special characters with standard characters for file system compatible filenames */
	/* mod 041117 to remove spaces as well */
		string= replace(string, fromCharCode(178), "\\^2"); /* superscript 2 */
		string= replace(string, fromCharCode(179), "\\^3"); /* superscript 3 UTF-16 (decimal) */
		string= replace(string, fromCharCode(0x207B) + fromCharCode(185), "\\^-1"); /* superscript -1 */
		string= replace(string, fromCharCode(0x207B) + fromCharCode(178), "\\^-2"); /* superscript -2 */
		string= replace(string, fromCharCode(181), "u"); /* micron units */
		string= replace(string, fromCharCode(197), "Angstrom"); /* Ångström unit symbol */
		string= replace(string, fromCharCode(0x2009) + fromCharCode(0x00B0), "deg"); /* replace thin spaces degrees combination */
		string= replace(string, fromCharCode(0x2009), "_"); /* Replace thin spaces  */
		string= replace(string, " ", "_"); /* Replace spaces - these can be a problem with image combination */
		string= replace(string, "_\\+", "\\+"); /* Clean up autofilenames */
		string= replace(string, "\\+\\+", "\\+"); /* Clean up autofilenames */
		string= replace(string, "__", "_"); /* Clean up autofilenames */
		return string;
	}
}