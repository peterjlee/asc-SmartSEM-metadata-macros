/*
	This macro adds multiple operating parameters extracted from SmartSEM metadata to a copy of the image.
	This requires the tiff_tags plugin written by Joachim Wesner that can be downloaded from http://rsbweb.nih.gov/ij/plugins/tiff-tags.html
	Originally it was based on the scale extracting macro here: https://rsb.info.nih.gov/ij/macros/SetScaleFromTiffTag.txt but as usual things got a little out of hand . . .
	Peter J. Lee Applied Superconductivity Center at National High Magnetic Field Laboratory.
	Version v170411 removes spaces in image names to fix issue with new image combinations.
	v180725 Adds system fonts to font list.
	v190506 Removed redundant functions.
	+ v200706 Changed imageDepth variable name added macro label.	5/16/2022 12:46 PM latest function updates f6: updated pad function.
	+ v220629-30 Switched to using Bio-Formats to extract headers as newer CZSEM headers are too long for "TIFF_Tags.getTag", path, "34118". Removed no-longer used functions
		Unfortunately characters do not import correctly from Bioformats so an additional edit is typically required.
		f1: updated colors
 */
macro "Add Multiple Lines of SEM Metadata to Image" {
	macroL = "CZSEM_Annotator_v220701-f1.ijm";
	/* We will assume you are using an up to date imageJ */
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
	orInfo = getMetadata("Info");
	iSEMName = indexOf(orInfo,"Sem = ");
	orPath = getDir("image") + getInfo("image.filename");
	if(iSEMName<0){
		/* If the standard CZ SEM info is missing use BioFormats to retrieve metaData */
		if(File.exists(orPath)) {
			run("Bio-Formats", "open=[" + orPath + "] color_mode=Default rois_import=[ROI manager] view=[Standard ImageJ] stack_order=Default");
			bioFMeta = getMetadata("Info");
			close();
			setMetadata("Info",bioFMeta);
		}
	}
	orInfo = getMetadata("Info");
	SEMName = getValueFromImageInfo(orInfo,"Sem = ",10,0,"Not found");
	if (SEMName=="Not found") exit("SEM metadata was not found for the selected image");
	/* Find bad characters */
	degTxt = "?";
	muTxt = "?";
	sup2 = "?";
	if(indexOf(orInfo,"?")>=0 || indexOf(orInfo,"?")>=0) badCharFound = true;
	else badCharFound = false;
	iDeg1 = indexOf(orInfo,"Temperature");
	if (iDeg1>0) {
		degTxt1 = substring(orInfo,iDeg1, iDeg1+20);
		iDeg2 = indexOf(degTxt1,"C");
		if(iDeg2>0) degTxt = substring(degTxt1,iDeg2-1,iDeg2);
	}
	iMu1 = indexOf(orInfo,"Aperture Size");
	if (iMu1>0){
		muTxt1 = substring(orInfo,iMu1, iMu1+25);
		iMu2 = indexOf(muTxt1,"m");
		if(iMu2>0) muTxt = substring(muTxt1,iMu2-1,iMu2);
	}
	iSup2a = indexOf(orInfo,"Db 1");
	if (iSup2a>0){
		sup2Txt1 = substring(orInfo,iSup2a, iSup2a+15);
		iSup2b = indexOf(sup2Txt1,"nm");
		if(iSup2b>0) sup2Txt = substring(sup2Txt1,iSup2b+2,iSup2b+3);
	}
	infoLines = split(orInfo, "\n");
	lInfoLines = lengthOf(infoLines);
	fParams1 = newArray("SEM: ","Date: ", "Time: ", "Sample ID: ", "User Name: ", "File Name: ","Photo No. : ","EHT: ");
	fStageParams = newArray("Stage at T: ", "Tilt Angle: ", "Tilt Corrn.: ", "Stage Angle: ", "Stage at X: ", "Stage at Y: ",  "Stage at Z: ");
	fImageParams = newArray("Signal A: ","Image Pixel Size: ", "Mag: ","Height: ", "Width: ", "Brightness: ", "Contrast: ");
	fBeamParams = newArray("Fil I: ", "WD: ", "Aperture Size: ");
	fScanParams = newArray("Noise Reduction: ", "Scan Speed: ","Cycle Time: ","Line Time: ", "N", "Line Avg.Count","Scan Rotation: ");
	favoriteParameters = Array.concat(fParams1,fBeamParams,fImageParams,fScanParams,fStageParams);
	// print(lInfoLines);
	/* clean up headers for uniformity */
	fInfoLines = newArray;
	for (i=0,j=0;i<lInfoLines;i++){  /* clean up SmartSEM headers for uniformity */
		showProgress(i,lInfoLines);
		showStatus("Unifying format...");
		filteredTag = replace(infoLines[i],"="," : ");
		if (startsWith(filteredTag,"Sem ")) filteredTag = replace(filteredTag,"Sem ","SEM ");
		filteredTag = replace(filteredTag,":"," : ");
		while (indexOf(filteredTag,"  ")>=0) filteredTag = replace(filteredTag,"  "," ");
		filteredTag = replace(filteredTag," : ",": ");
		/* try to fix issues with BioFormats symbols . . .  Not successful so far */
		if(badCharFound){
			showStatus("Fixing bad symbol: " + badSymbol);
			// if (endsWith(filteredTag," " + degTxt)) filteredTag = replace(filteredTag," " + degTxt, fromCharCode(0x00B0)+fromCharCode(0x2009));
			// else if (endsWith(filteredTag," " + degTxt+"C"))) filteredTag = replace(filteredTag," " + degTxt+"C", " " + fromCharCode(0x00B0)+fromCharCode(0x2009) + "C");
			// else if (endsWith(filteredTag," " + muTxt+"m")) filteredTag = replace(filteredTag," " + muTxt+"m", " " + getInfo("micrometer.abbreviation"));
			// else if (endsWith(filteredTag," " + muTxt+"A"," ")) filteredTag = replace(filteredTag," " + muTxt+"A", " " + fromCharCode(0x03BC) + "A");
			if (endsWith(filteredTag," " + degTxt)) filteredTag = replace(filteredTag," " + degTxt, " degrees");
			else if (endsWith(filteredTag," nm" + sup2Txt)) filteredTag = replace(filteredTag," nm" + sup2Txt, " nm^2");
			else if (endsWith(filteredTag," " + degTxt+"C"))) filteredTag = replace(filteredTag," " + degTxt+"C", " degrees C");
			else if (endsWith(filteredTag," " + muTxt+"m")) filteredTag = replace(filteredTag," " + muTxt+"m", " um"));
			else if (endsWith(filteredTag," " + muTxt+"A"," ")) filteredTag = replace(filteredTag," " + muTxt+"A", " uA");
		}
		if (indexOf(filteredTag,":")>0){
			fInfoLines[j] = filteredTag;
			j++;
		}
	}
	showStatus("Format unified");
	infoLines = Array.sort(fInfoLines);
	metaParameters = newArray();
	metaValues = newArray();
	metaTags = newArray();
	zeissSEMName = "";
	smartSEMVersion = "";
	smartSEMVNo = 0;
	for (i=0,j=0;i<lInfoLines;i++){
		showProgress(i,lInfoLines);
		showStatus("Filtering parameters...");
		iValue = indexOf(infoLines[i],"=");
		if (iValue<0)iValue = indexOf(infoLines[i],":");
		if (iValue>0){
			parameter = substring(infoLines[i],0,iValue);
			paraFilters = newArray(" ","Argon ","Cryo ","Flood Gun ","Pa ","Pb ","AP_AS","Stage goto","Stage high","Stage low", "Nano Tips");
			for(k=0,go=true;k<lengthOf(paraFilters);k++){
				if(startsWith(parameter,paraFilters[k])){
					go = false;
					k = lengthOf(paraFilters);
				}
			}
			while(endsWith(parameter," ")) parameter = substring(parameter,0,lengthOf(parameter)-1);
			if(go) {
				value = substring(infoLines[i],iValue+1);
				while(startsWith(value," ")) value = substring(value,1);
				while(endsWith(value," ")) value = substring(value,0,lengthOf(value)-1);
				if (value!=""){
					metaValues[j] = value;
					metaParameters[j] = parameter;
					// metaTags[j] = infoLines[i];
					metaTags[j] = parameter + ": " + value;
					if (startsWith(parameter, "SEM: ")) zeissSEMName = value;
					if (startsWith(parameter, "Version = ")){
						smartSEMVersion = "" + value;
						smartSEMVNo = parseInt(substring(value, indexOf(value,"V")+1,indexOf(value,".")));
						// print(smartSEMVersion,smartSEMVNo);
					}
					j++;
				}
			}
		}
	}
	lMetaTags = j;
	lFPs = lengthOf(favoriteParameters);
	favoriteAnnos = newArray();
	for(i=0,f=0;i<lFPs;i++){
		showProgress(i,lFPs);
		showStatus("Assembling favorite parameters...");
		for(j=0;j<lMetaTags;j++){
			if (startsWith(metaTags[j],favoriteParameters[i])){
				favoriteAnnos[f] = metaTags[j];
				f++;
			}
		}
	}
	fLines = f;
	alternativeChoices = newArray("-none-", "-blank-", "-user input-");
	textChoices = Array.concat(alternativeChoices, favoriteAnnos, alternativeChoices, metaTags);
	textChoiceLines = minOf(screenHeight / 48, fLines);
	imageWidth = getWidth();
	imageHeight = getHeight();
	imageDims = imageHeight + imageWidth;
	imageDepth = bitDepth();
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
	Dialog.create(zeissSEMName + " Basic Label Options: " + macroL);
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
		colorChoices = newArray("white", "black", "off-white", "off-black", "light_gray", "gray", "dark_gray");
		colorChoicesStd = newArray("red", "cyan", "pink", "green", "blue", "magenta", "yellow", "orange");
		colorChoicesMod = newArray("garnet", "gold", "aqua_modern", "blue_accent_modern", "blue_dark_modern", "blue_modern", "blue_honolulu", "gray_modern", "green_dark_modern", "green_modern", "green_modern_accent", "green_spring_accent", "orange_modern", "pink_modern", "purple_modern", "red_n_modern", "red_modern", "tan_modern", "violet_modern", "yellow_modern");
		colorChoicesNeon = newArray("jazzberry_jam", "radical_red", "wild_watermelon", "outrageous_orange", "supernova_orange", "atomic_tangerine", "neon_carrot", "sunglow", "laser_lemon", "electric_lime", "screamin'_green", "magic_mint", "blizzard_blue", "dodger_blue", "shocking_pink", "razzle_dazzle_rose", "hot_magenta");
		if (imageDepth==24) colorChoices = Array.concat(colorChoices,colorChoicesStd,colorChoicesMod,colorChoicesNeon);
		Dialog.setInsets(-30, 60, 0);
		Dialog.addChoice("Text color:", colorChoices, colorChoices[0]);
		fontStyleChoice = newArray("bold", "bold antialiased", "italic", "italic antialiased", "bold italic", "bold italic antialiased", "unstyled");
		Dialog.addChoice("Font style:", fontStyleChoice, fontStyleChoice[1]);
		fontNameChoice = getFontChoiceList();
		Dialog.addChoice("Font name:", fontNameChoice, fontNameChoice[0]);
		Dialog.addChoice("Outline color:", colorChoices, colorChoices[1]);
		Dialog.addNumber("Limit to first",textChoiceLines,0,3,"lines");
		Dialog.addCheckbox("Edit all entries in next dialog \(correct symbols etc.\)?",true);
		for (i=0; i<textChoiceLines; i++){
			showProgress(i,textChoiceLines);
			showStatus("Creating parameter selection dialog list...");
			Dialog.addChoice("Line "+(i+1)+":", textChoices, textChoices[i+3]);
		}
		showStatus("Created parameter selection dialog list");
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
		textChoiceLines = Dialog.getNumber();
		textInputLines = newArray(textChoiceLines);
		editAll = Dialog.getCheckbox();
		for (i=0; i<textChoiceLines; i++)
			textInputLines[i] = Dialog.getChoice();
		tweakFormat = Dialog.getChoice();
/*	*/
	if (tweakFormat=="Yes") {
	Dialog.create("Advanced Formatting Options");
		Dialog.addNumber("X offset from edge \(for corners only\)", selOffsetX,0,1,"pixels");
		Dialog.addNumber("Y offset from edge \(for corners only\)", selOffsetY,0,1,"pixels");
		Dialog.addNumber("Line Spacing", lineSpacing,0,3,"");
		Dialog.addNumber("Outline stroke:", outlineStroke,0,3,"% of font size");
		Dialog.addChoice("Outline (background) color:", colorChoices, colorChoices[1]);
		Dialog.addNumber("Shadow drop: " + fromCharCode(0x00B1), shadowDrop,0,3,"% of font size"); /* � symbol: 0x00B1 plus/minus */
		Dialog.addNumber("Shadow displacement right: " + fromCharCode(0x00B1), shadowDrop,0,3,"% of font size");
		Dialog.addNumber("Shadow Gaussian blur:", floor(0.75 * shadowDrop),0,3,"% of font size");
		Dialog.addNumber("Shadow Darkness:", 75,0,3,"%\(darkest = 100%\)");
		// Dialog.addMessage("The following \"Inner Shadow\" options do not change the Overlay Labels");
		Dialog.addNumber("Inner shadow drop: " + fromCharCode(0x00B1), dIShO,0,3,"% of font size");
		Dialog.addNumber("Inner displacement right: " + fromCharCode(0x00B1), dIShO,0,3,"% of font size");
		Dialog.addNumber("Inner shadow mean blur:",floor(dIShO/2),1,3,"% of font size");
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
	showStatus("Preparing annotation...");
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
	setFont(fontName, fontSize, fontStyle);
	longestStringWidth = 0;
	textOutputLines = newArray();
	if (editAll){
		Dialog.create("Edit all chosen lines");
		Dialog.addMessage("Replace text with \"-none-\" or \"-blank-\" to skip or space lines");
		Dialog.addMessage("Labels: Use \"^\" for superscript numbers, i.e. ^2 = " + fromCharCode(178) + ", um = "+ fromCharCode(181) + "m, degrees = " + fromCharCode(0x00B0) + " etc.");
		for (i=0,j=0; i<textChoiceLines; i++) {
			if (textInputLines[i]!="-none-"){
				if (textInputLines[i]=="-user input-") Dialog.addString("Label Line "+(j+1)+":","", 30);
				else Dialog.addString("Label Line "+(j+1)+":",textInputLines[i], lengthOf(textInputLines[i]));
				j++;
			}
		}
		textChoiceLines = j;
		Dialog.show();
		for (i=0,j=0; i<textChoiceLines; i++) {
			newLine = cleanLabel(Dialog.getString());
			if (newLine!= "-none-"){
				textOutputLines[j] = cleanLabel(newLine);
				if (getStringWidth(newLine)>longestStringWidth) longestStringWidth = getStringWidth(newLine);
				j++;
			}
		}
	}
	else {
		for (i=0,j=0; i<textChoiceLines; i++) {
			if (textInputLines[i]!="-none-"){
				if (textInputLines[i]=="-user input-") {
					Dialog.create("Basic Label Options");
					Dialog.addString("Label Line "+(i+1)+":","", 30);
					Dialog.show();
					textOutputLines[j] = cleanLabel(Dialog.getString());
				}
				else if (textInputLines[i]=="-blank-") textOutputLines[j] = "";
				else textOutputLines[j] = "" + cleanLabel(textInputLines[i]);
				if (getStringWidth(textOutputLines[j])>longestStringWidth) longestStringWidth = getStringWidth(textOutputLines[j]);
				j++;
			}
		}
	}
	textOutNumber = j;
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
	setBatchMode(true);
	roiManager("show none");
	run("Duplicate...", t+"+text");
	labeledImage = getTitle();
	newImage("label_mask", "8-bit black", imageWidth, imageHeight, 1);
	roiManager("deselect");
	run("Select None");
	/* Draw summary over top of labels */
	setFont(fontName,fontSize, fontStyle);
	setColor(255,255,255);
	for (i=0; i<textOutNumber; i++) {
		drawString(textOutputLines[i], textLabelX, textLabelY);
		textLabelY += lineSpacing * fontSize;
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
	memFlush(200);
/*
	( 8(|)	( 8(|)	Functions	@@@@@:-)	@@@@@:-)
*/
	function cleanLabel(string) {
		/*  ImageJ macro default file encoding (ANSI or UTF-8) varies with platform so non-ASCII characters may vary: hence the need to always use fromCharCode instead of special characters.
		v180611 added "degreeC"
		v200604	fromCharCode(0x207B) removed as superscript hyphen not working reliably
		v220630 added degrees */
		string= replace(string, "\\^2", fromCharCode(178)); /* superscript 2 */
		string= replace(string, "\\^3", fromCharCode(179)); /* superscript 3 UTF-16 (decimal) */
		string= replace(string, "\\^-"+fromCharCode(185), "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-"+fromCharCode(178), "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-^1", "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-^2", "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-1", "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-2", "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-^1", "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-^2", "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "(?<![A-Za-z0-9])u(?=m)", fromCharCode(181)); /* micron units */
		string= replace(string, "\\b[aA]ngstrom\\b", fromCharCode(197)); /* �ngstr�m unit symbol */
		string= replace(string, "  ", " "); /* Replace double spaces with single spaces */
		string= replace(string, "_", " "); /* Replace underlines with space as thin spaces (fromCharCode(0x2009)) not working reliably  */
		string= replace(string, "px", "pixels"); /* Expand pixel abbreviation */
		string= replace(string, "degreeC", fromCharCode(0x00B0) + "C"); /* Degree symbol for dialog boxes */
		// string = replace(string, " " + fromCharCode(0x00B0), fromCharCode(0x2009) + fromCharCode(0x00B0)); /* Replace normal space before degree symbol with thin space */
		// string= replace(string, " �", fromCharCode(0x2009) + fromCharCode(0x00B0)); /* Replace normal space before degree symbol with thin space */
		string= replace(string, "sigma", fromCharCode(0x03C3)); /* sigma for tight spaces */
		string= replace(string, "plusminus", fromCharCode(0x00B1)); /* plus or minus */
		string= replace(string, "degrees", fromCharCode(0x00B0)); /* plus or minus */
		return string;
	}
	function closeImageByTitle(windowTitle) {  /* Cannot be used with tables */
		/* v181002 reselects original image at end if open
		   v200925 uses "while" instead of if so it can also remove duplicates
		*/
		oIID = getImageID();
        while (isOpen(windowTitle)) {
			selectWindow(windowTitle);
			close();
		}
		if (isOpen(oIID)) selectImage(oIID);
	}
	function createInnerShadowFromMask() {
		/* Requires previous run of: imageDepth = bitDepth();
		because this version works with different bitDepths
		v161104
		v200706 changed image depth variable name.
		*/
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
		if (imageDepth==16 || imageDepth==32) run(imageDepth + "-bit");
		run("Enhance Contrast...", "saturated=0 normalize");
		run("Invert");  /* Create an image that can be subtracted - this works better for color than Min */
		divider = (100 / abs(innerShadowDarkness));
		run("Divide...", "value=[divider]");
	}
	function createShadowDropFromMask() {
		/* Requires previous run of: imageDepth = bitDepth();
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
		if (imageDepth==16 || imageDepth==32) run(imageDepth + "-bit");
		run("Enhance Contrast...", "saturated=0 normalize");
		divider = (100 / abs(shadowDarkness));
		run("Divide...", "value=[divider]");
	}
	/*	Color Functions	*/
	function getColorArrayFromColorName(colorName) {
		/* v180828 added Fluorescent Colors
		   v181017-8 added off-white and off-black for use in gif transparency and also added safe exit if no color match found
		   v191211 added Cyan
		   v211022 all names lower-case, all spaces to underscores v220225 Added more hash value comments as a reference v220706 restores missing magenta
		   REQUIRES restoreExit function.  56 Colors
		*/
		if (colorName == "white") cA = newArray(255,255,255);
		else if (colorName == "black") cA = newArray(0,0,0);
		else if (colorName == "off-white") cA = newArray(245,245,245);
		else if (colorName == "off-black") cA = newArray(10,10,10);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "off-black") cA = newArray(10,10,10);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "red") cA = newArray(255,0,0);
		else if (colorName == "pink") cA = newArray(255, 192, 203);
		else if (colorName == "green") cA = newArray(0,255,0); /* #00FF00 AKA Lime green */
		else if (colorName == "blue") cA = newArray(0,0,255);
		else if (colorName == "magenta") cA = newArray(255,0,255); /* #FF00FF */
		else if (colorName == "yellow") cA = newArray(255,255,0);
		else if (colorName == "orange") cA = newArray(255, 165, 0);
		else if (colorName == "cyan") cA = newArray(0, 255, 255);
		else if (colorName == "garnet") cA = newArray(120,47,64);
		else if (colorName == "gold") cA = newArray(206,184,136);
		else if (colorName == "aqua_modern") cA = newArray(75,172,198); /* #4bacc6 AKA "Viking" aqua */
		else if (colorName == "blue_accent_modern") cA = newArray(79,129,189); /* #4f81bd */
		else if (colorName == "blue_dark_modern") cA = newArray(31,73,125); /* #1F497D */
		else if (colorName == "blue_modern") cA = newArray(58,93,174); /* #3a5dae */
		else if (colorName == "blue_honolulu") cA = newArray(0,118,182); /* Honolulu Blue #30076B6 */
		else if (colorName == "gray_modern") cA = newArray(83,86,90); /* bright gray #53565A */
		else if (colorName == "green_dark_modern") cA = newArray(121,133,65); /* Wasabi #798541 */
		else if (colorName == "green_modern") cA = newArray(155,187,89); /* #9bbb59 AKA "Chelsea Cucumber" */
		else if (colorName == "green_modern_accent") cA = newArray(214,228,187); /* #D6E4BB AKA "Gin" */
		else if (colorName == "green_spring_accent") cA = newArray(0,255,102); /* #00FF66 AKA "Spring Green" */
		else if (colorName == "orange_modern") cA = newArray(247,150,70); /* #f79646 tan hide, light orange */
		else if (colorName == "pink_modern") cA = newArray(255,105,180); /* hot pink #ff69b4 */
		else if (colorName == "purple_modern") cA = newArray(128,100,162); /* blue-magenta, purple paradise #8064A2 */
		else if (colorName == "jazzberry_jam") cA = newArray(165,11,94);
		else if (colorName == "red_n_modern") cA = newArray(227,24,55);
		else if (colorName == "red_modern") cA = newArray(192,80,77);
		else if (colorName == "tan_modern") cA = newArray(238,236,225);
		else if (colorName == "violet_modern") cA = newArray(76,65,132);
		else if (colorName == "yellow_modern") cA = newArray(247,238,69);
		/* Fluorescent Colors https://www.w3schools.com/colors/colors_crayola.asp */
		else if (colorName == "radical_red") cA = newArray(255,53,94);			/* #FF355E */
		else if (colorName == "wild_watermelon") cA = newArray(253,91,120);		/* #FD5B78 */
		else if (colorName == "outrageous_orange") cA = newArray(255,96,55);	/* #FF6037 */
		else if (colorName == "supernova_orange") cA = newArray(255,191,63);	/* FFBF3F Supernova Neon Orange*/
		else if (colorName == "atomic_tangerine") cA = newArray(255,153,102);	/* #FF9966 */
		else if (colorName == "neon_carrot") cA = newArray(255,153,51);			/* #FF9933 */
		else if (colorName == "sunglow") cA = newArray(255,204,51); 			/* #FFCC33 */
		else if (colorName == "laser_lemon") cA = newArray(255,255,102); 		/* #FFFF66 "Unmellow Yellow" */
		else if (colorName == "electric_lime") cA = newArray(204,255,0); 		/* #CCFF00 */
		else if (colorName == "screamin'_green") cA = newArray(102,255,102); 	/* #66FF66 */
		else if (colorName == "magic_mint") cA = newArray(170,240,209); 		/* #AAF0D1 */
		else if (colorName == "blizzard_blue") cA = newArray(80,191,230); 		/* #50BFE6 Malibu */
		else if (colorName == "dodger_blue") cA = newArray(9,159,255);			/* #099FFF Dodger Neon Blue */
		else if (colorName == "shocking_pink") cA = newArray(255,110,255);		/* #FF6EFF Ultra Pink */
		else if (colorName == "razzle_dazzle_rose") cA = newArray(238,52,210); 	/* #EE34D2 */
		else if (colorName == "hot_magenta") cA = newArray(255,0,204);			/* #FF00CC AKA Purple Pizzazz */
		else restoreExit("No color match to " + colorName);
		return cA;
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
	  /* This version by Tiago Ferreira 6/6/2022 eliminates the toString macro function in some IJ versions */
	  if (lengthOf(n)==1) n= "0"+n; return n;
	  if (lengthOf(""+n)==1) n= "0"+n; return n;
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
	function getValueFromImageInfo(infoFile,infoName,bufferLength,endTrim,errorReturn){
		/* v220629 1st version: pjl */
		iInfoName = indexOf(infoFile,infoName);
		if (iInfoName<0) return errorReturn;
		else{
			sTL = lengthOf(infoName);
			outString = substring(infoFile,iInfoName+sTL,iInfoName+sTL+bufferLength);
			outString = substring(outString,0,indexOf(outString, "\n") - endTrim); /* removes bad degree symbol for instance */
			while (endsWith(outString," ")) outString = substring(outString,0,lengthOf(outString)-1);
			while (startsWith(outString," ")) outString = substring(outString,1);
			return outString;
		}
	}
	function memFlush(waitTime) {
		run("Reset...", "reset=[Undo Buffer]");
		wait(waitTime);
		run("Reset...", "reset=[Locked Image]");
		wait(waitTime);
		call("java.lang.System.gc"); /* force a garbage collection */
		wait(waitTime);
	}
	function restoreExit(message){ /* Make a clean exit from a macro, restoring previous settings */
		/* v200305 first version using memFlush function
			v220316 if message is blank this should still work now
		*/
		restoreSettings(); /* Restore previous settings before exiting */
		setBatchMode("exit & display"); /* Probably not necessary if exiting gracefully but otherwise harmless */
		memFlush(200);
		if (message!="") exit(message);
		else exit;
	}
	function unCleanLabel(string) {
	/* v161104 This function replaces special characters with standard characters for file system compatible filenames.
	+ 041117b to remove spaces as well.
	+ v220126 added getInfo("micrometer.abbreviation").
	+ v220128 add loops that allow removal of multiple duplication.
	+ v220131 fixed so that suffix cleanup works even if extensions are included.
	*/
		/* Remove bad characters */
		string= replace(string, fromCharCode(178), "\\^2"); /* superscript 2 */
		string= replace(string, fromCharCode(179), "\\^3"); /* superscript 3 UTF-16 (decimal) */
		string= replace(string, fromCharCode(0xFE63) + fromCharCode(185), "\\^-1"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string= replace(string, fromCharCode(0xFE63) + fromCharCode(178), "\\^-2"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string= replace(string, fromCharCode(181), "u"); /* micron units */
		string= replace(string, getInfo("micrometer.abbreviation"), "um"); /* micron units */
		string= replace(string, fromCharCode(197), "Angstrom"); /* �ngstr�m unit symbol */
		string= replace(string, fromCharCode(0x2009) + fromCharCode(0x00B0), "deg"); /* replace thin spaces degrees combination */
		string= replace(string, fromCharCode(0x2009), "_"); /* Replace thin spaces  */
		string= replace(string, "%", "pc"); /* % causes issues with html listing */
		string= replace(string, " ", "_"); /* Replace spaces - these can be a problem with image combination */
		/* Remove duplicate strings */
		unwantedDupes = newArray("8bit","lzw");
		for (i=0; i<lengthOf(unwantedDupes); i++){
			iLast = lastIndexOf(string,unwantedDupes[i]);
			iFirst = indexOf(string,unwantedDupes[i]);
			if (iFirst!=iLast) {
				string = substring(string,0,iFirst) + substring(string,iFirst + lengthOf(unwantedDupes[i]));
				i=-1; /* check again */
			}
		}
		unwantedDbls = newArray("_-","-_","__","--","\\+\\+");
		for (i=0; i<lengthOf(unwantedDbls); i++){
			iFirst = indexOf(string,unwantedDbls[i]);
			if (iFirst>=0) {
				string = substring(string,0,iFirst) + substring(string,iFirst + lengthOf(unwantedDbls[i])/2);
				i=-1; /* check again */
			}
		}
		string= replace(string, "_\\+", "\\+"); /* Clean up autofilenames */
		/* cleanup suffixes */
		unwantedSuffixes = newArray(" ","_","-","\\+"); /* things you don't wasn't to end a filename with */
		extStart = lastIndexOf(string,".");
		sL = lengthOf(string);
		if (sL-extStart<=4) extIncl = true;
		else extIncl = false;
		if (extIncl){
			preString = substring(string,0,extStart);
			extString = substring(string,extStart);
		}
		else {
			preString = string;
			extString = "";
		}
		for (i=0; i<lengthOf(unwantedSuffixes); i++){
			sL = lengthOf(preString);
			if (endsWith(preString,unwantedSuffixes[i])) {
				preString = substring(preString,0,sL-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
				i=-1; /* check one more time */
			}
		}
		if (!endsWith(preString,"_lzw") && !endsWith(preString,"_lzw.")) preString = replace(preString, "_lzw", ""); /* Only want to keep this if it is at the end */
		string = preString + extString;
		/* End of suffix cleanup */
		return string;
	}
}