/*
	This macro adds multiple operating parameters extracted from SmartSEM metadata to a copy of the image.
	This requires the tiff_tags plugin written by Joachim Wesner that can be downloaded from http://rsbweb.nih.gov/ij/plugins/tiff-tags.html
	Originally it was based on the scale extracting macro here: https://rsb.info.nih.gov/ij/macros/SetScaleFromTiffTag.txt but as usual things got a little out of hand . . .
	Peter J. Lee Applied Superconductivity Center at National High Magnetic Field Laboratory.
	Version v170411 removes spaces in image names to fix issue with new image combinations.
	v180725 Adds system fonts to font list.
	v190506 Removed redundant functions.
	+ v200706 Changed imageDepth variable name added macro label.	5/16/2022 12:46 PM latest function updates f6: updated pad function.
	+ v220811 Switched to stripping header text as string.
	+ v220812 Tweaked ZapGremlins and embeds scale if no scale is currently used. F1 updated color functions.
	+ v220824 In-row label spacing now a user variable. Changed defaults to expansion and added checks for color choices.
	+ v221013 Options added to save space for scale bar and output labels to log window.
	+ v221207 Changed to using "NUL" character to find end of header by editing ZapGremlins and extractTIFFHeaderInfoToArray functions. f1 (053023) updated multiple functions
	+ v230803: Replaced getDir for 1.54g10. F1: Updated indexOf functions. f2: getColorArrayFromColorName_v230908.
	+ v231020: Export filename option added and timestamp.
	+ v231128: Removed "!" from showStatus for stability.  F1: Replaced function: pad.
	+ v240118: Renames image. Updated cleanLabel function to remove odd EVO characters. f1: Updated getColorFromColorName function (012324). F2 : updated function unCleanLabel.
 */
macro "Add Multiple Lines of CZSEM Metadata to Image" {
	macroL = "CZSEM_Annotator_v240118-f2.ijm";
	/* We will assume you are using an up to date imageJ */
	saveSettings; /* for restoreExit */
	setBatchMode(true);
	if (selectionType>=0) {
		selEType = selectionType;
		selectionExists = true;
		getSelectionBounds(selEX, selEY, selEWidth, selEHeight);
	}
	else selectionExists = false;
	degCh = fromCharCode(0x00B0);
	micronS = getInfo("micrometer.abbreviation");
	sepSpace = "";
	diagnostics = false;
	t = getTitle();
	tNoExt = getTitleWOKnownExtension();
	tNoExt = unCleanLabel(tNoExt);
	imagePath = getDirectory("image");
	// Checks to see if a Ramp legend rather than the image has been selected by accident
	if (matches(t, ".*Ramp.*")==1) showMessageWithCancel("Title contains \"Ramp\"", "Do you want to label" + t + " ?");
	infoLines = split(getMetadata("Info"), "\n");
	iSEMName = indexOfArrayThatStartsWith(infoLines,"Sem = ",-1);
	orPath = imagePath + getInfo("image.filename");
	metaDataAdded = false;
	if(iSEMName<0){
		/* If the standard CZ SEM info is missing use BioFormats to retrieve metaData */
		headerStart = getTime();
		if(File.exists(orPath)) {
			fullFileString = File.openAsString(orPath);
			smartSEMInfos = extractTIFFHeaderInfoToArray(fullFileString,"DP_","SAMPLE_ID",300,"\n",sepSpace,"End of Header",newArray("SmartSEM header not found")); /* (tag,beginTag,endTag,endBuffer,lfRep,tabRep,nulRep,default) */
			headerExtracted = getTime();
			IJ.log("Time to extract header: " + (headerExtracted-headerStart)/1000 + " s");
			if (smartSEMInfos[0]!= "SmartSEM header not found"){
				for (i=0;i<smartSEMInfos.length;i++) smartSEMInfos = Array.deleteIndex(smartSEMInfos, i); /* For SmartSEM images ONLY: Remove unnecessary info title lines */
				smartSEMInfoString = arrayToString(smartSEMInfos,"\n");
				imagejInfo = getMetadata("Info");
				if (imagejInfo==""){
					setMetadata("Info",smartSEMInfoString);
					IJ.log("SmartSEM header added to ImageJ metaData");
					metaDataAdded = true;
				}
			}
			fullFileString = "";
			call("java.lang.System.gc");
		}
	}
	headerExtractionComplete = getTime();
	infoLines = split(getMetadata("Info"), "\n");
	iSEMName = indexOfArrayThatStartsWith(infoLines,"Sem = ",-1);
	if (iSEMName>=0){
		SEMName = substring(infoLines[iSEMName],6);
		zeissSEMNames = newArray("Ultra 40 XB","1540XB","EVO 10");
		zeissShortNames = newArray("EsB","XB","EVO10");
		iMicroscope = indexOfArrayThatContains(zeissSEMNames,SEMName,-1);
		if (iMicroscope>=0) SEMName = zeissShortNames[iMicroscope];
		getPixelSize(unit, pixelWidth, pixelHeight);
		if (pixelWidth!=pixelHeight || pixelWidth==1 || unit=="" || unit=="inches" || unit=="pixels"){
			iCZScaleValue  = indexOfArrayThatStartsWith(smartSEMInfos,"Image Pixel Size = ",-1);
			if (iCZScaleValue>=0){
				CZScaleValue = smartSEMInfos[iCZScaleValue];
				CZScaleString = substring(CZScaleValue,19);
				CZScale = split(CZScaleString," ");
				distPerPixel = parseFloat(CZScale[0]);
				CZScale = sensibleUnits(distPerPixel,CZScale[1]);
				distPerPixel = parseFloat(CZScale[0]);
				CZUnit = CZScale[1];
				run("Set Scale...", "distance=1 known=&distPerPixel pixel=1 unit=&CZUnit");
			}
		}
	}
	else SEMName = "Not found";
	lInfoLines = lengthOf(infoLines);
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
	lInfoLines = lengthOf(infoLines);
	for (i=0,j=0;i<lInfoLines;i++){
		showProgress(i,lInfoLines);
		showStatus("Filtering parameters..." + i + " out of " + lInfoLines + " reducing by " + i-j);
		iValue = indexOf(infoLines[i],"=");
		if (iValue<0)iValue = indexOf(infoLines[i],":");
		if (iValue>0){
			parameter = substring(infoLines[i],0,iValue);
			paraFilters = newArray(" ","Argon ","Cryo ","Flood Gun ","Pa ","Pb ","AP_AS","Stage goto","Stage high","Stage low", "Nano Tips");
			if (startsWith(SEMName,"EVO")) paraFilters = Array.concat(paraFilters,"FIB ", "STEM ", "GIS ", "Beam deceleration", "VP ", "V ", "ESD ", "Extractor ", "Aa ", "Da ", "Db ", "Deconvolution ", "InLens", "Jazz ", "Fisheye ");
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
					metaTags[j] = parameter + ": " + cleanLabel(value);
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
	fSessionInfos = newArray("SEM: ","Date: ", "Time: ", "User Name: ", "Photo No.: ", "File Name: ", "Images: "); /* NOTE: there should be no space before ':' and a space after */
	fParams1 = newArray("Sample ID: ", "EHT: ");
	fStageParams = newArray("Stage at T: ", "Tilt Angle: ", "Stage at X: ", "Stage at Y: ",  "Stage at Z: ");
	fImageParams = newArray("Signal A: ","Image Pixel Size: ", "Mag: ","Height: ", "Width: ", "Brightness: ", "Contrast: ","Tilt Corrn.: ");
	if (indexOfArray(metaTags,"Scan Rot: On",-1)>=0) fImageParams = Array.concat(fImageParams,"Scan Rotation: ");
	// if (indexOfArray(metaTags,"Stage Angle corrn.: On",-1)>=0) fImageParams = Array.concat(fImageParams,"Stage Angle corrn.: ", "Stage Angle: "); /* This is just a joystick movement correction /*
	if (startsWith(SEMName,"EVO")){
		fBeamParams = newArray("WD: ", "Aperture Size: ", "Spot Size: ", "I Probe: ","Filament Type: ","Filament Age: ");
		if (indexOfArray(metaTags,"OptiBeam Is: On",-1)>=0) fBeamParams = Array.concat("OptiBeam Mode: ",fBeamParams);
	}
	else fBeamParams = newArray("Fil I: ", "WD: ", "Aperture Size: ");
	fScanParams = newArray("Noise Reduction: ", "Scan Speed: ","Cycle Time: ","Line Time: ", "N: ", "Line Avg.Count: ");
	favoriteParameters = Array.concat(fParams1,fBeamParams,fImageParams,fScanParams,fStageParams,fSessionInfos);	
	lFPs = lengthOf(favoriteParameters);
	favoriteAnnos = newArray();
	for(i=0,f=0;i<lFPs;i++){
		showProgress(i,lFPs);
		showStatus("Assembling favorite parameters..." + i + " to " + f + " favorites");
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
	textChoiceLines = minOf(screenHeight / 30, fLines+4);
	imageWidth = getWidth();
	imageHeight = getHeight();
	imageDims = imageHeight + imageWidth;
	imageDepth = bitDepth();
	fontSize = maxOf(9,round(imageDims/140)); /* default font size is small for this variant */
	lineSpacing = 1;
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
	selOffsetX = round(1 + imageWidth/250); /* default offset of label from edge */
	selOffsetY = round(1 + imageHeight/250); /* default offset of label from edge */
	/* Then Dialog . . . */
	colorChoices = newArray("white", "black", "off-white", "off-black", "light_gray", "gray", "dark_gray");
	colorChoicesStd = newArray("red", "green", "blue", "cyan", "magenta", "yellow", "pink", "orange", "violet");
	colorChoicesMod = newArray("garnet", "gold", "aqua_modern", "blue_accent_modern", "blue_dark_modern", "blue_modern", "blue_honolulu", "gray_modern", "green_dark_modern", "green_modern", "green_modern_accent", "green_spring_accent", "orange_modern", "pink_modern", "purple_modern", "red_n_modern", "red_modern", "tan_modern", "violet_modern", "yellow_modern");
	colorChoicesNeon = newArray("jazzberry_jam", "radical_red", "wild_watermelon", "outrageous_orange", "supernova_orange", "atomic_tangerine", "neon_carrot", "sunglow", "laser_lemon", "electric_lime", "screamin'_green", "magic_mint", "blizzard_blue", "dodger_blue", "shocking_pink", "razzle_dazzle_rose", "hot_magenta");
	if (imageDepth==24) colorChoices = Array.concat(colorChoices,colorChoicesStd,colorChoicesMod,colorChoicesNeon);
	textLocChoices = newArray("Column Left", "Column Right", "Center", "Rows Bottom Left", "Rows Bottom Right", "Center of New Selection");
	if (selectionExists) {
		textLocChoices = Array.concat(textLocChoices, "At Selection");
		defLoc = textLocChoices.length-1;
	}
	fontStyleChoice = newArray("bold", "bold antialiased", "italic", "italic antialiased", "bold italic", "bold italic antialiased", "unstyled");
	fontNameChoice = getFontChoiceList();
	showStatus("Preparing dialog list");
	dialog1Creation = getTime();
	if (imageDepth==24){
		iTC = indexOfArray(colorChoices, call("ij.Prefs.get", "asc.czsem.anno.font.color",colorChoices[0]),0);
		iOC = indexOfArray(colorChoices, call("ij.Prefs.get", "asc.czsem.anno.outline.color",colorChoices[1]),1);
	}
	else{
		iTC = indexOfArray(colorChoices, call("ij.Prefs.get", "asc.czsem.anno.font.gray",colorChoices[0]),0);
		iOC = indexOfArray(colorChoices, call("ij.Prefs.get", "asc.czsem.anno.outline.gray",colorChoices[1]),1);
	}
	iTextLoc = indexOfArray(textLocChoices, call("ij.Prefs.get", "asc.czsem.anno.textLoc", textLocChoices[3]),3);
	sepSpaceN = parseInt(call("ij.Prefs.get", "asc.czsem.anno.sepSpaceN",4));
	/* ASC Dialog style: */
	infoColor = "#006db0"; /* Honolulu blue */
	instructionColor = "#798541"; /* green_dark_modern (121,133,65) AKA Wasabi */
	infoWarningColor = "#ff69b4"; /* pink_modern AKA hot pink */
	infoFontSize = 12;
	Dialog.create(zeissSEMName + " Basic Label Options: " + macroL);
		if (metaDataAdded) Dialog.addMessage("The Zeiss metadata was added to the ImageJ metadata", infoFontSize, infoColor);
		if (imageDepth==16 || imageDepth==32) Dialog.addCheckbox("Image depth is " + imageDepth + ": Use 8-bit copy for annotation", true);
		Dialog.addChoice("Location:", textLocChoices, textLocChoices[iTextLoc]);
		if (selectionExists) {
			Dialog.addNumber("Selection Bounds: X start = ", selEX);
			Dialog.addNumber("Selection Bounds: Y start = ", selEY);
			Dialog.addNumber("Selection Bounds: Width = ", selEWidth);
			Dialog.addNumber("Selection Bounds: Height = ", selEHeight);
		}
		else Dialog.addCheckbox("Expand canvas to accommodate label \(uses Outline\/Background color below\)?", true);
		Dialog.addNumber("Font size:", fontSize, 0, 3,"");
		Dialog.addChoice("Text color:", colorChoices, colorChoices[iTC]);
		Dialog.addToSameRow();
		Dialog.addChoice("Outline\/Background color:", colorChoices, colorChoices[iOC]);
		Dialog.addChoice("Font style:", fontStyleChoice, fontStyleChoice[1]);
		Dialog.addToSameRow();
		Dialog.addChoice("Font name:", fontNameChoice, fontNameChoice[0]);
		Dialog.addNumber("Label in-row Spacing",sepSpaceN,0,3,"spaces");
		Dialog.addToSameRow();
		Dialog.addNumber("Leave space for scale bar",0,0,3,"% of image width \(bottom\) or height \(left\/right\)");
		Dialog.addNumber("Limit to first",fLines,0,3,"lines");
		extraOptions = newArray("Don't annotate, just text output", "Tweak text formatting?", "Export metadata to csv file", "Edit all entries in next dialog \(correct symbols etc.\)?", "Print annotation list to log window?", "Diagnostics");
		extraOptionsChecks = newArray(false, false, true, false, false, false);
		Dialog.setInsets(10, 20, 5)
		Dialog.addCheckboxGroup(2, 3, extraOptions, extraOptionsChecks);
		showStatus("!Creating parameter selection dialog list items", "flash yellow"); /* standard colors only - Do not flash color updates as this will slow things down */
		for (i=0, r=1; i<textChoiceLines; i++, r++){
			showProgress(i, textChoiceLines);
			if (r>1){
				r=0;
				Dialog.addToSameRow();
			}
			Dialog.addChoice("Line "+(i+1)+":", textChoices, textChoices[i+3]);
		}
		showStatus("Created parameter selection dialog list", "green"); /* standard colors only */
		// Dialog.setInsets(100, 20, 20);
		Dialog.addMessage("Pull down for more options: User-input, blank lines and ALL other parameters", infoFontSize, instructionColor);
		Dialog.addString("Export file prefix", tNoExt, 20);
		dialog1Created = getTime();
	Dialog.show();
		if (imageDepth==16 || imageDepth==32) reduceDepth = Dialog.getCheckbox();
		textLocChoice = Dialog.getChoice();
		if (selectionExists) {
			selEX = Dialog.getNumber();
			selEY = Dialog.getNumber();
			selEWidth = Dialog.getNumber();
			selEHeight = Dialog.getNumber();
			expanded = false;
		}
		else expanded = Dialog.getCheckbox();
		fontSize =  Dialog.getNumber();
		fontColor = Dialog.getChoice();
		outlineColor = Dialog.getChoice();
		fontStyle = Dialog.getChoice();
		fontName = Dialog.getChoice();
		sepSpaceN = Dialog.getNumber();
		scaleBarPC = Dialog.getNumber();
		textChoiceLines = Dialog.getNumber();
		textInputLines = newArray(textChoiceLines);
		noAnno = Dialog.getCheckbox();
		tweakFormat = Dialog.getCheckbox();
		exportToCSV = Dialog.getCheckbox();
		editAll = Dialog.getCheckbox();
		printOut = Dialog.getCheckbox();
		for (i=0; i<textChoiceLines; i++)
			textInputLines[i] = Dialog.getChoice();
		exportPrefix = Dialog.getString();
/*	*/
	showStatus("Showing Dialog");
	if (diagnostics){
		IJ.log("Time to filter parameters: " + (dialog1Creation-headerExtractionComplete)/1000 + " s");
		IJ.log("Time to create dialog for parameter selection: " + (dialog1Created-dialog1Creation)/1000 + " s");
	}
	if (exportToCSV){
		exportString = arrayToString(metaTags, "\n");
		exportString = replace(exportString, ": ", ",");
		exportString = "Parameter,Value,Note: original ': ' in metatag replaced by comma to separate parameters from values\n" + exportString;
		exportString += "\nGenerated by " + macroL;
		timeStamp = getDateTimeCode(); /* saveString does not like to overwrite files so a timestamp should make the file name unique */
		timeStamp = substring(timeStamp, 0, lastIndexOf(timeStamp, "m"));
		exportPath = imagePath + exportPrefix + "_" + timeStamp + ".csv";
		File.saveString(exportString, exportPath);
	}
	if(!noAnno){
		for (i=0; i<sepSpaceN; i++) sepSpace += " "; 
		if (outlineColor==fontColor) tweakFormat = true; /* Forces a second look at formatting */
		if (startsWith(textLocChoice,"Center")) expanded = false;
		if (tweakFormat) {
			Dialog.create("Advanced Formatting Options");
				Dialog.addNumber("X offset from edge \(for corners only\)", selOffsetX,0,1,"pixels");
				Dialog.addNumber("Y offset from edge \(for corners only\)", selOffsetY,0,1,"pixels");
				Dialog.addNumber("Line Spacing", lineSpacing,0,3,"");
				if (outlineColor==fontColor){
					Dialog.addMessage("Outline color and text color should be different", infoFontSize, infoWarningColor);
					Dialog.addChoice("Text color:", colorChoices, colorChoices[0]);
					Dialog.addChoice("Outline color:", colorChoices, colorChoices[1]);
				}
				if (!expanded){
					Dialog.addNumber("Outline stroke:", outlineStroke,0,3,"% of font size");
					Dialog.addNumber("Shadow drop: " + fromCharCode(0x00B1), shadowDrop,0,3,"% of font size"); /* ï¿½ symbol: 0x00B1 plus/minus */
					Dialog.addNumber("Shadow displacement right: " + fromCharCode(0x00B1), shadowDrop,0,3,"% of font size");
					Dialog.addNumber("Shadow Gaussian blur:", floor(0.75 * shadowDrop),0,3,"% of font size");
					Dialog.addNumber("Shadow Darkness:", 75,0,3,"%\(darkest = 100%\)");
					// Dialog.addMessage("The following \"Inner Shadow\" options do not change the Overlay Labels");
					Dialog.addNumber("Inner shadow drop: " + fromCharCode(0x00B1), dIShO,0,3,"% of font size");
					Dialog.addNumber("Inner displacement right: " + fromCharCode(0x00B1), dIShO,0,3,"% of font size");
					Dialog.addNumber("Inner shadow mean blur:",floor(dIShO/2),1,3,"% of font size");
					Dialog.addNumber("Inner Shadow Darkness:", 20,0,3,"% \(darkest = 100%\)");
				}
				else {
					Dialog.addMessage("No shadows or outlines are used if the labels are not located on the image", infoFontSize, infoColor);
					Dialog.addChoice("Expanded region background color:", colorChoices, colorChoices[1]);
				}
			Dialog.show();
				selOffsetX = Dialog.getNumber();
				selOffsetY = Dialog.getNumber();
				lineSpacing = Dialog.getNumber();
				if (outlineColor==fontColor){		
					fontColor = Dialog.getChoice();
					outlineColor = Dialog.getChoice();
				}
				if (!expanded){
					outlineStroke = Dialog.getNumber();
					shadowDrop = Dialog.getNumber();
					shadowDisp = Dialog.getNumber();
					shadowBlur = Dialog.getNumber();
					shadowDarkness = Dialog.getNumber();
					innerShadowDrop = Dialog.getNumber();
					innerShadowDisp = Dialog.getNumber();
					innerShadowBlur = Dialog.getNumber();
					innerShadowDarkness = Dialog.getNumber();
			}
		}
		if (imageDepth==24){
			call("ij.Prefs.set", "asc.czsem.anno.font.color", fontColor);
			call("ij.Prefs.set", "asc.czsem.anno.outline.color", outlineColor);
		}
		else {
			call("ij.Prefs.set", "asc.czsem.anno.font.gray", fontColor);
			call("ij.Prefs.set", "asc.czsem.anno.outline.gray", outlineColor);
		}
		call("ij.Prefs.set", "asc.czsem.anno.sepSpaceN", sepSpaceN);
		call("ij.Prefs.set", "asc.czsem.anno.textLoc", textLocChoice);
		fontColors = getColorArrayFromColorName(fontColor);
		outlineColors = getColorArrayFromColorName(outlineColor);
		fontFactor = fontSize/100;
		if (!expanded){
			negAdj = 0.5;  /* negative offsets appear exaggerated at full displacement */
			showStatus("Preparing annotation...");
			if (shadowDrop<0) shadowDrop *= negAdj;
			if (shadowDisp<0) shadowDisp *= negAdj;
			if (shadowBlur<0) shadowBlur *= negAdj;
			if (innerShadowDrop<0) innerShadowDrop *= negAdj;
			if (innerShadowDisp<0) innerShadowDisp *= negAdj;
			if (innerShadowBlur<0) innerShadowBlur *= negAdj;
			outlineStroke = floor(fontFactor * outlineStroke);
			shadowDrop = floor(fontFactor * shadowDrop);
			shadowDisp = floor(fontFactor * shadowDisp);
			shadowBlur = floor(fontFactor * shadowBlur);
			innerShadowDrop = floor(fontFactor * innerShadowDrop);
			innerShadowDisp = floor(fontFactor * innerShadowDisp);
			innerShadowBlur = floor(fontFactor * innerShadowBlur);
		}
		if (fontStyle=="unstyled") fontStyle="";
		setFont(fontName, fontSize, fontStyle);
	}
	textOutNumber = 0;
	longestStringWidth = 0;
	textOutputLines = newArray();
	if (editAll){
		Dialog.create("Edit all chosen lines");
		Dialog.addMessage("Replace text with \"-none-\" or \"-blank-\" to skip or space lines. For labels: Use \"^\" for superscript numbers, i.e. ^2 = " + fromCharCode(178) + ", um = "+ fromCharCode(181) + "m, degrees = " + fromCharCode(0x00B0) + " etc.", infoFontSize, instructionColor);
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
	if (printOut){
		IJ.log ("Metadata for " + t + ":");
		for (i=0; i<textOutputLines.length; i++) IJ.log(textOutputLines[i]);
		IJ.log ("----------------------------");
	}
	if (!noAnno){
		fontHeight = getValue("font.height");
		textOutNumber = j;
		if(startsWith(textLocChoice,"Rows")){
			textRows = newArray("");
			rowText = "";
			longestStringWidth = 0;
			for (i=0,j=0; i<textOutNumber; i++) {
				labelLength = getStringWidth(textOutputLines[i] + sepSpace);
				rowLength = getStringWidth(rowText);
				if ((rowLength+labelLength+2*selOffsetX) < imageWidth*(1-scaleBarPC/100))	rowText += textOutputLines[i] + sepSpace;
				else {
					textRows[j] = rowText;
					if (rowLength>longestStringWidth) longestStringWidth = rowLength;
					rowText = textOutputLines[i] + sepSpace;
					j++;
				}
			}
			nRows = j+1;
			if(nRows==1) longestStringWidth = rowLength;
			linesSpace = lineSpacing * nRows * fontHeight - (lineSpacing*fontHeight/2);
		}
		else linesSpace = lineSpacing * (textOutNumber-1) * fontHeight + imageHeight*scaleBarPC/100;
		if (textLocChoice == "Column Left") {
			selEX = selOffsetX;
			selEY = selOffsetY + imageHeight*scaleBarPC/100;
		} else if (textLocChoice == "Column Right") {
			selEX = imageWidth - longestStringWidth - selOffsetX;
			selEY = selOffsetY + imageHeight*scaleBarPC/100;
		} else if (textLocChoice == "Center") {
			selEX = round((imageWidth - longestStringWidth)/2);
			selEY = round((imageHeight - linesSpace)/2);
		} else if (textLocChoice == "Rows Bottom Left") {
			selEX = selOffsetX + imageWidth*scaleBarPC/100;
			selEY = imageHeight - (selOffsetY + linesSpace);
		} else if (textLocChoice == "Rows Bottom Right") {
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
		} else if (selectionExists) {
			selEX = selEX + round((selEWidth/2) - longestStringWidth/1.5);
			selEY = selEY + round((selEHeight/2) - (linesSpace/2));
		}
		run("Select None");
		if (selEY<=1.5*fontHeight)
			selEY += fontHeight;
		if (selEX<selOffsetX) selEX = selOffsetX;
		endX = selEX + longestStringWidth;
		if ((endX+selOffsetX)>imageWidth) selEX = imageWidth - longestStringWidth - selOffsetX;
		textLabelX = selEX;
		textLabelY = selEY;
		// setBatchMode(true);
		roiManager("show none");
		/* now rename image to reflect changes and avoid danger of annotated copy overwriting original */
		newT = tNoExt + "+SmartSEM Annotation";
		run("Duplicate...", newT);
		if (imageDepth==16 || imageDepth==32){
			if (reduceDepth){
				newT += "_8bit";
				run("Enhance Contrast...", "saturated=0");
				run("8-bit");
				rename(newT);
			}
		}
		labeledImage = getTitle();
		if (expanded){
			if (outlineColor!=fontColor){
				setBackgroundColor(outlineColors[0],outlineColors[1],outlineColors[2]);
				setColor(fontColors[0],fontColors[1],fontColors[2]);
			}
			if (startsWith(textLocChoice,"Rows Bottom")){
				newImageHeight = imageHeight+linesSpace+selOffsetY;
				run("Canvas Size...", "width="+imageWidth+" height="+newImageHeight+" position=Top-Left");
				textLabelY = imageHeight+selOffsetY+fontHeight;
			}
			else {
				newImageWidth = imageWidth+longestStringWidth+2*selOffsetX;
				if (startsWith(textLocChoice,"Column Left")) run("Canvas Size...", "width="+newImageWidth+" height="+imageHeight+" position=Top-Right");
				else if (startsWith(textLocChoice,"Column Right")){
					run("Canvas Size...", "width="+newImageWidth+" height="+imageHeight+" position=Top-Left");
					textLabelX = imageWidth + selOffsetX;
				}
			}
		}
		else{	
			newImage("label_mask", "8-bit black", imageWidth, imageHeight, 1);
			roiManager("deselect");
			run("Select None");
			/* Draw summary over top of labels */
			setFont(fontName,fontSize, fontStyle);
			setColor(255,255,255);
		}
		if(startsWith(textLocChoice,"Rows")){
			for (i=0; i<nRows-1; i++) {
				drawString(textRows[i], textLabelX, textLabelY);
				textLabelY += lineSpacing * fontHeight;
			}		
		}
		else {
			for (i=0; i<textOutNumber; i++) {
				drawString(textOutputLines[i], textLabelX, textLabelY);
				textLabelY += lineSpacing * fontHeight;
			}
		}
		if (!expanded){	
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
			setBackgroundFromColorName(fontColor);
			run("Clear");
			run("Select None");
			if (isOpen("inner_shadow")) imageCalculator("Subtract", labeledImage,"inner_shadow");
			closeImageByTitle("shadow");
			closeImageByTitle("inner_shadow");
			closeImageByTitle("label_mask");
			selectWindow(labeledImage);
		}
	}
	rename(tNoExt + "+Anno");
	setBatchMode("exit & display");
	showStatus("Fancy SmartSEM annotation macro finished", "flash image green");
	memFlush(200);
}
/*
	( 8(|)	( 8(|)	Functions	@@@@@:-)	@@@@@:-)
*/
	function arrayToString(array, delimiter){
		/* 1st version April 2019 PJL
			v190722 Modified to handle zero length array
			v220307 += restored for else line */
		string = "";
		for (i=0; i<array.length; i++){
			if (i==0) string += array[0];
			else  string += delimiter + array[i];
		}
		return string;
	}
	function cleanLabel(string) {
		/*  ImageJ macro default file encoding (ANSI or UTF-8) varies with platform so non-ASCII characters may vary: hence the need to always use fromCharCode instead of special characters.
		v180611 added "degreeC"
		v200604	fromCharCode(0x207B) removed as superscript hyphen not working reliably
		v220630 added degrees v220812 Changed Ångström unit code
		v231005 Weird Excel characters added, micron unit correction
		v240118 Weird EVO characters fixed */
		string= replace(string, "\\^2", fromCharCode(178)); /* superscript 2 */
		string= replace(string, "\\^3", fromCharCode(179)); /* superscript 3 UTF-16 (decimal) */
		string= replace(string, "\\^-" + fromCharCode(185), "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-" + fromCharCode(178), "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-^1", "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-^2", "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-1", "-"  + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-2", "-"  + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-^1", "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-^2", "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "(?<![A-Za-z0-9])u(?=m)", fromCharCode(181)); /* micron units */
		string= replace(string, "\\b[aA]ngstrom\\b", fromCharCode(0x212B)); /* Ångström unit symbol */
		string= replace(string, "  ", " "); /* Replace double spaces with single spaces */
		string= replace(string, "_", " "); /* Replace underlines with space as thin spaces (fromCharCode(0x2009)) not working reliably  */
		string= replace(string, "px", "pixels"); /* Expand pixel abbreviation */
		string= replace(string, "degreeC", fromCharCode(0x00B0) + "C"); /* Degree symbol for dialog boxes */
		// string = replace(string, " " + fromCharCode(0x00B0), fromCharCode(0x2009) + fromCharCode(0x00B0)); /* Replace normal space before degree symbol with thin space */
		// string= replace(string, " °", fromCharCode(0x2009) + fromCharCode(0x00B0)); /* Replace normal space before degree symbol with thin space */
		string= replace(string, "sigma", fromCharCode(0x03C3)); /* sigma for tight spaces */
		string= replace(string, "plusminus", fromCharCode(0x00B1)); /* plus or minus */
		string= replace(string, "degrees", fromCharCode(0x00B0)); /* plus or minus */
		if (indexOf(string,"mý")>1) string = substring(string, 0, indexOf(string,"mý")-1) + getInfo("micrometer.abbreviation") + fromCharCode(178);
		/* Fixes for weird EVO character issue: */
		oddEVOUs = newArray(fromCharCode(181)+"m", getInfo("micrometer.abbreviation"), fromCharCode(0x212B), fromCharCode(0x00B0));
		for (i=0; i<oddEVOUs.length; i++)
			if ((lastIndexOf(string, " ") + 2)==lastIndexOf(string,oddEVOUs[i])) string = substring(string, 0, lastIndexOf(string, " ") + 1) + substring(string, lastIndexOf(string, " ") + 2, string.length);
		/* End of EVO specific fix */
		string = string.replace("µ", fromCharCode(181));
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
	function extractTIFFHeaderInfoToArray(tag,beginTag,endTag,endBuffer,lfRep,tabRep,nulRep,default){
	/* v220801 1st version
	  v220803 REQUIRES zapGremlins function
	  v220805 Changed to work from previously imported string so that string can be reused.
	  v221207 Looks for NUL character to define end of header (requires v221207 or later version of zapGremins) and adds separation space as input parameter
		*/
	iEndTag = lastIndexOf(tag,endTag);
	if (iEndTag>=0){
		if (iEndTag+endBuffer>tag.length) endBuffer = tag.length-iEndTag;
		tag = substring(tag,0,iEndTag+endBuffer);
		iStartTag = indexOf(tag,beginTag);
		if (iStartTag>=0){
			tag = substring(tag,iStartTag);
			tag = zapGremlins(tag,lfRep,tabRep,nulRep,true);
			iEndOfLine = indexOf(tag,nulRep);
			if(iEndOfLine<1){
				tagEndString = substring(tag,lengthOf(tag)-endBuffer,lengthOf(tag));
				iEndOfLine = lengthOf(tag)-endBuffer + indexOf(tagEndString,"\n");
			}
			tag = substring(tag,0,iEndOfLine);
			headerArray = split(tag,"\n");
			return headerArray;
		}
	}
	else return default;
	}
	/*	Modified BAR Color Functions	*/
	function getColorArrayFromColorName(colorName) {
		/* v180828 added Fluorescent Colors
		   v181017-8 added off-white and off-black for use in gif transparency and also added safe exit if no color match found
		   v191211 added Cyan
		   v211022 all names lower-case, all spaces to underscores v220225 Added more hash value comments as a reference v220706 restores missing magenta
		   v230130 Added more descriptions and modified order.
		   v230908: Returns "white" array if not match is found and logs issues without exiting.
		   v240123: Removed duplicate entries: Now 53 unique colors 
		*/
		functionL = "getColorArrayFromColorName_v240123";
		cA = newArray(255,255,255); /* defaults to white */
		if (colorName == "white") cA = newArray(255,255,255);
		else if (colorName == "black") cA = newArray(0,0,0);
		else if (colorName == "off-white") cA = newArray(245,245,245);
		else if (colorName == "off-black") cA = newArray(10,10,10);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "red") cA = newArray(255,0,0);
		else if (colorName == "green") cA = newArray(0,255,0);					/* #00FF00 AKA Lime green */
		else if (colorName == "blue") cA = newArray(0,0,255);
		else if (colorName == "cyan") cA = newArray(0, 255, 255);
		else if (colorName == "yellow") cA = newArray(255,255,0);
		else if (colorName == "magenta") cA = newArray(255,0,255);				/* #FF00FF */
		else if (colorName == "pink") cA = newArray(255, 192, 203);
		else if (colorName == "violet") cA = newArray(127,0,255);
		else if (colorName == "orange") cA = newArray(255, 165, 0);
		else if (colorName == "garnet") cA = newArray(120,47,64);				/* #782F40 */
		else if (colorName == "gold") cA = newArray(206,184,136);				/* #CEB888 */
		else if (colorName == "aqua_modern") cA = newArray(75,172,198);		/* #4bacc6 AKA "Viking" aqua */
		else if (colorName == "blue_accent_modern") cA = newArray(79,129,189); /* #4f81bd */
		else if (colorName == "blue_dark_modern") cA = newArray(31,73,125);	/* #1F497D */
		else if (colorName == "blue_honolulu") cA = newArray(0,118,182);		/* Honolulu Blue #006db0 */
		else if (colorName == "blue_modern") cA = newArray(58,93,174);			/* #3a5dae */
		else if (colorName == "gray_modern") cA = newArray(83,86,90);			/* bright gray #53565A */
		else if (colorName == "green_dark_modern") cA = newArray(121,133,65);	/* Wasabi #798541 */
		else if (colorName == "green_modern") cA = newArray(155,187,89);		/* #9bbb59 AKA "Chelsea Cucumber" */
		else if (colorName == "green_modern_accent") cA = newArray(214,228,187); /* #D6E4BB AKA "Gin" */
		else if (colorName == "green_spring_accent") cA = newArray(0,255,102);	/* #00FF66 AKA "Spring Green" */
		else if (colorName == "orange_modern") cA = newArray(247,150,70);		/* #f79646 tan hide, light orange */
		else if (colorName == "pink_modern") cA = newArray(255,105,180);		/* hot pink #ff69b4 */
		else if (colorName == "purple_modern") cA = newArray(128,100,162);		/* blue-magenta, purple paradise #8064A2 */
		else if (colorName == "jazzberry_jam") cA = newArray(165,11,94);
		else if (colorName == "red_n_modern") cA = newArray(227,24,55);
		else if (colorName == "red_modern") cA = newArray(192,80,77);
		else if (colorName == "tan_modern") cA = newArray(238,236,225);
		else if (colorName == "violet_modern") cA = newArray(76,65,132);
		else if (colorName == "yellow_modern") cA = newArray(247,238,69);
		/* Fluorescent Colors https://www.w3schools.com/colors/colors_crayola.asp */
		else if (colorName == "radical_red") cA = newArray(255,53,94);			/* #FF355E */
		else if (colorName == "wild_watermelon") cA = newArray(253,91,120);	/* #FD5B78 */
		else if (colorName == "shocking_pink") cA = newArray(255,110,255);		/* #FF6EFF Ultra Pink */
		else if (colorName == "razzle_dazzle_rose") cA = newArray(238,52,210);	/* #EE34D2 */
		else if (colorName == "hot_magenta") cA = newArray(255,0,204);			/* #FF00CC AKA Purple Pizzazz */
		else if (colorName == "outrageous_orange") cA = newArray(255,96,55);	/* #FF6037 */
		else if (colorName == "supernova_orange") cA = newArray(255,191,63);	/* FFBF3F Supernova Neon Orange*/
		else if (colorName == "sunglow") cA = newArray(255,204,51);			/* #FFCC33 */
		else if (colorName == "neon_carrot") cA = newArray(255,153,51);		/* #FF9933 */
		else if (colorName == "atomic_tangerine") cA = newArray(255,153,102);	/* #FF9966 */
		else if (colorName == "laser_lemon") cA = newArray(255,255,102);		/* #FFFF66 "Unmellow Yellow" */
		else if (colorName == "electric_lime") cA = newArray(204,255,0);		/* #CCFF00 */
		else if (colorName == "screamin'_green") cA = newArray(102,255,102);	/* #66FF66 */
		else if (colorName == "magic_mint") cA = newArray(170,240,209);		/* #AAF0D1 */
		else if (colorName == "blizzard_blue") cA = newArray(80,191,230);		/* #50BFE6 Malibu */
		else if (colorName == "dodger_blue") cA = newArray(9,159,255);			/* #099FFF Dodger Neon Blue */
		else IJ.log(colorName + " not found in " + functionL + ": Color defaulted to white");
		return cA;
	}
	function setBackgroundFromColorName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setBackgroundColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	function getHexColorFromColorName(colorNameString) {
		/* v231207: Uses IJ String.pad instead of function: pad */
		colorArray = getColorArrayFromColorName(colorNameString);
		 r = toHex(colorArray[0]); g = toHex(colorArray[1]); b = toHex(colorArray[2]);
		 hexName= "#" + "" + String.pad(r, 2) + "" + String.pad(g, 2) + "" + String.pad(b, 2);
		 return hexName;
	}	
	/*	End of BAR Color Functions	*/
  	function getDateTimeCode() {
		/* v211014 based on getDateCode v170823 */
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		month = month + 1; /* Month starts at zero, presumably to be used in array */
		if(month<10) monthStr = "0" + month;
		else monthStr = ""  + month;
		if (dayOfMonth<10) dayOfMonth = "0" + dayOfMonth;
		dateCodeUS = monthStr+dayOfMonth+substring(year,2)+"-"+hour+"h"+minute+"m";
		return dateCodeUS;
	}
  	function getFontChoiceList() {
		/*	v180723 first version
			v180828 Changed order of favorites. v190108 Longer list of favorites. v230209 Minor optimization.
			v230919 You can add a list of fonts that do not produce good results with the macro. 230921 more exclusions.
		*/
		systemFonts = getFontList();
		IJFonts = newArray("SansSerif", "Serif", "Monospaced");
		fontNameChoices = Array.concat(IJFonts,systemFonts);
		blackFonts = Array.filter(fontNameChoices, "([A-Za-z]+.*[bB]l.*k)");
		eBFonts = Array.filter(fontNameChoices,  "([A-Za-z]+.*[Ee]xtra.*[Bb]old)");
		uBFonts = Array.filter(fontNameChoices,  "([A-Za-z]+.*[Uu]ltra.*[Bb]old)");
		fontNameChoices = Array.concat(blackFonts, eBFonts, uBFonts, fontNameChoices); /* 'Black' and Extra and Extra Bold fonts work best */
		faveFontList = newArray("Your favorite fonts here", "Arial Black", "Myriad Pro Black", "Myriad Pro Black Cond", "Noto Sans Blk", "Noto Sans Disp Cond Blk", "Open Sans ExtraBold", "Roboto Black", "Alegreya Black", "Alegreya Sans Black", "Tahoma Bold", "Calibri Bold", "Helvetica", "SansSerif", "Calibri", "Roboto", "Tahoma", "Times New Roman Bold", "Times Bold", "Goldman Sans Black", "Goldman Sans", "Serif");
		/* Some fonts or font families don't work well with ASC macros, typically they do not support all useful symbols, they can be excluded here using the .* regular expression */
		offFontList = newArray("Alegreya SC Black", "Archivo.*", "Arial Rounded.*", "Bodon.*", "Cooper.*", "Eras.*", "Fira.*", "Gill Sans.*", "Lato.*", "Libre.*", "Lucida.*",  "Merriweather.*", "Montserrat.*", "Nunito.*", "Olympia.*", "Poppins.*", "Rockwell.*", "Tw Cen.*", "Wingdings.*", "ZWAdobe.*"); /* These don't work so well. Use a ".*" to remove families */
		faveFontListCheck = newArray(faveFontList.length);
		for (i=0,counter=0; i<faveFontList.length; i++) {
			for (j=0; j<fontNameChoices.length; j++) {
				if (faveFontList[i] == fontNameChoices[j]) {
					faveFontListCheck[counter] = faveFontList[i];
					j = fontNameChoices.length;
					counter++;
				}
			}
		}
		faveFontListCheck = Array.trim(faveFontListCheck, counter);
		for (i=0; i<fontNameChoices.length; i++) {
			for (j=0; j<offFontList.length; j++){
				if (fontNameChoices[i]==offFontList[j]) fontNameChoices = Array.deleteIndex(fontNameChoices, i);
				if (endsWith(offFontList[j],".*")){
					if (startsWith(fontNameChoices[i], substring(offFontList[j], 0, indexOf(offFontList[j],".*")))){
						fontNameChoices = Array.deleteIndex(fontNameChoices, i);
						i = maxOf(0, i-1); 
					} 
					// fontNameChoices = Array.filter(fontNameChoices, "(^" + offFontList[j] + ")"); /* RegEx not working and very slow */
				} 
			} 
		}
		fontNameChoices = Array.concat(faveFontListCheck, fontNameChoices);
		for (i=0; i<fontNameChoices.length; i++) {
			for (j=i+1; j<fontNameChoices.length; j++)
				if (fontNameChoices[i]==fontNameChoices[j]) fontNameChoices = Array.deleteIndex(fontNameChoices, j);
		}
		return fontNameChoices;
	}
	function getSelectionFromMask(sel_M){
		/* v220920 only inverts if full image selection */
		batchMode = is("Batch Mode"); /* Store batch status mode before toggling */
		if (!batchMode) setBatchMode(true); /* Toggle batch mode on if previously off */
		tempID = getImageID();
		selectWindow(sel_M);
		run("Create Selection"); /* Selection inverted perhaps because the mask has an inverted LUT? */
		getSelectionBounds(gSelX,gSelY,gWidth,gHeight);
		if(gSelX==0 && gSelY==0 && gWidth==Image.width && gHeight==Image.height)	run("Make Inverse");
		run("Select None");
		selectImage(tempID);
		run("Restore Selection");
		if (!batchMode) setBatchMode(false); /* Return to original batch mode setting */
	}
	function getTitleWOKnownExtension() {
	/*	v230904: 1st version  PJL Applied Superconductivity Center
		v230908: Simplified to replace only  NOTE: precede with "" + , i.e. oTitle = "" + getTitleWOKnownExtension();
	*/ 
		newTitle = getTitle();
		lcExtns = newArray(".avi", ".csv", ".dsx", ".gif", ".jpeg", ".jpg", ".jp2", "_lzw.", ".ols", ".png", ".tiff", ".tif",  ".txt", ".vsi", ".xlsx", ".xls");
		/* Note: Always list 4 character extensions before 3 character extensions */
		nExtns = lcExtns.length;
		for (i=0; i<nExtns && lastIndexOf(newTitle,".")>0; i++){
			newTitle = replace(newTitle, lcExtns[i], "");
			newTitle = replace(newTitle, toUpperCase(lcExtns[i]), "");
		} 
		return newTitle;
	}
	function indexOfArray(array, value, default) {
		/* v190423 Adds "default" parameter (use -1 for backwards compatibility). Returns only first found value
			v230902 Limits default value to array size */
		index = minOf(lengthOf(array) - 1, default);
		for (i=0; i<lengthOf(array); i++){
			if (array[i]==value) {
				index = i;
				i = lengthOf(array);
			}
		}
	  return index;
	}
	function indexOfArrayThatContains(array, value, default) {
		/* Like indexOfArray but partial matches possible
			v190423 Only first match returned, v220801 adds default.
			v230902 Limits default value to array size */
		indexFound = minOf(lengthOf(array) - 1, default);
		for (i=0; i<lengthOf(array); i++){
			if (indexOf(array[i], value)>=0){
				indexFound = i;
				i = lengthOf(array);
			}
		}
		return indexFound;
	}
	function indexOfArrayThatStartsWith(array, value, default) {
		/* Like indexOfArray but partial matches possible
			v220804 1st version
			v230902 Limits default value to array size */
		indexFound = minOf(lengthOf(array) - 1, default);
		for (i=0; i<lengthOf(array); i++){
			if (indexOf(array[i], value)==0){
				indexFound = i;
				i = lengthOf(array);
			}
		}
		return indexFound;
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
			REQUIRES saveSettings AND memFlush
		*/
		restoreSettings(); /* Restore previous settings before exiting */
		setBatchMode("exit & display"); /* Probably not necessary if exiting gracefully but otherwise harmless */
		memFlush(200);
		if (message!="") exit(message);
		else exit;
	}
	function sensibleUnits(pixelW,inUnit){
		/* v220805: 1st version
			v230808: Converts inches to mm automatically.
			v230809: Removed exit, just logs without change.
		*/
		kUnits = newArray("m", "mm", getInfo("micrometer.abbreviation"), "nm", "pm");
		if (inUnit=="inches"){
			inUnit = "mm";
			pixelW *= 25.4;
			IJ.log("Inches converted to mm units");
		}
		if(startsWith(inUnit,"micro") || endsWith(inUnit,"ons") || inUnit=="um" || inUnit=="µm") inUnit = kUnits[2];
		iInUnit = indexOfArray(kUnits,inUnit,-1);
		if (iInUnit<0) IJ.log("Scale unit \(" + inUnit + "\) not in unitChoices for sensible scale function, so units not optimized");
		else {
			while (round(pixelW)>50) {
				/* */
				pixelW /= 1000;
				iInUnit -= 1;
				inUnit = kUnits[iInUnit];
			}
			while (pixelW<0.02){
				pixelW *= 1000;
				iInUnit += 1;
				inUnit = kUnits[iInUnit];				
			}
		}
		outArray = Array.concat(pixelW,inUnit);
		return outArray;
	}
	function unCleanLabel(string) {
	/* v161104 This function replaces special characters with standard characters for file system compatible filenames.
	+ 041117b to remove spaces as well.
	+ v220126 added getInfo("micrometer.abbreviation").
	+ v220128 add loops that allow removal of multiple duplication.
	+ v220131 fixed so that suffix cleanup works even if extensions are included.
	+ v220616 Minor index range fix that does not seem to have an impact if macro is working as planned. v220715 added 8-bit to unwanted dupes. v220812 minor changes to micron and Ångström handling
	+ v231005 Replaced superscript abbreviations that did not work.
	+ v240124 Replace _+_ with +.
	*/
		/* Remove bad characters */
		string = string.replace(fromCharCode(178), "sup2"); /* superscript 2 */
		string = string.replace(fromCharCode(179), "sup3"); /* superscript 3 UTF-16 (decimal) */
		string = string.replace(fromCharCode(0xFE63) + fromCharCode(185), "sup-1"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string = string.replace(fromCharCode(0xFE63) + fromCharCode(178), "sup-2"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string = string.replace(fromCharCode(181) + "m", "um"); /* micron units */
		string = string.replace(getInfo("micrometer.abbreviation"), "um"); /* micron units */
		string = string.replace(fromCharCode(197), "Angstrom"); /* Ångström unit symbol */
		string = string.replace(fromCharCode(0x212B), "Angstrom"); /* the other Ångström unit symbol */
		string = string.replace(fromCharCode(0x2009) + fromCharCode(0x00B0), "deg"); /* replace thin spaces degrees combination */
		string = string.replace(fromCharCode(0x2009), "_"); /* Replace thin spaces  */
		string = string.replace("%", "pc"); /* % causes issues with html listing */
		string = string.replace(" ", "_"); /* Replace spaces - these can be a problem with image combination */
		/* Remove duplicate strings */
		unwantedDupes = newArray("8bit", "8-bit", "lzw");
		for (i=0; i<lengthOf(unwantedDupes); i++){
			iLast = lastIndexOf(string, unwantedDupes[i]);
			iFirst = indexOf(string, unwantedDupes[i]);
			if (iFirst!=iLast) {
				string = string.substring(0, iFirst) + string.substring(iFirst + lengthOf(unwantedDupes[i]));
				i = -1; /* check again */
			}
		}
		unwantedDbls = newArray("_-", "-_", "__", "--", "\\+\\+");
		for (i=0; i<lengthOf(unwantedDbls); i++){
			iFirst = indexOf(string, unwantedDbls[i]);
			if (iFirst>=0) {
				string = string.substring(0, iFirst) + string.substring(string, iFirst + lengthOf(unwantedDbls[i]) / 2);
				i = -1; /* check again */
			}
		}
		string = string.replace("_\\+", "\\+"); /* Clean up autofilenames */
		string = string.replace("\\+_", "\\+"); /* Clean up autofilenames */
		/* cleanup suffixes */
		unwantedSuffixes = newArray(" ", "_", "-", "\\+"); /* things you don't wasn't to end a filename with */
		extStart = lastIndexOf(string, ".");
		sL = lengthOf(string);
		if (sL-extStart<=4 && extStart>0) extIncl = true;
		else extIncl = false;
		if (extIncl){
			preString = substring(string, 0, extStart);
			extString = substring(string, extStart);
		}
		else {
			preString = string;
			extString = "";
		}
		for (i=0; i<lengthOf(unwantedSuffixes); i++){
			sL = lengthOf(preString);
			if (endsWith(preString, unwantedSuffixes[i])) {
				preString = substring(preString, 0, sL-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
				i=-1; /* check one more time */
			}
		}
		if (!endsWith(preString, "_lzw") && !endsWith(preString, "_lzw.")) preString = replace(preString, "_lzw", ""); /* Only want to keep this if it is at the end */
		string = preString + extString;
		/* End of suffix cleanup */
		return string;
	}
	function zapGremlins(inputString,lfRep,tabRep,nulRep,allElse){
	/* v220803 Just https://wsr.imagej.net//macros/ZapGremlins.txt
	 	Basic Latin decimal character numbers are listed here: https://en.wikipedia.org/wiki/List_of_Unicode_characters#Basic_Latin
		v220812: chars 181 and 63 is mu and 176 is the degree symbol which seem too valuable to risk loosing: this version allows more latin extended symbols, adds allElse option for light pruning
		v221207: Adds NUL character replacement
		 */
		requires("1.39f");
		LF=10; TAB=9; NUL=0; /* Carriage return = 13 */
		String.resetBuffer;
		n = lengthOf(inputString);
		for (i=0; i<n; i++) {
			c = charCodeAt(inputString, i);
			if (c==LF)
				String.append(lfRep);
			else if (c==TAB)
				String.append(tabRep);
			else if (c==NUL)
				String.append(nulRep);
			else if (c==63)
				String.append(fromCharCode(181) + "m");
			else if (c==197)
				String.append(fromCharCode(0x212B)); /* Ångström */
			else if (allElse)
				String.append(fromCharCode(c));
			else if ((c>=32 && c<=127) || (c>=176 && c<=186))
				String.append(fromCharCode(c));
		}
		return String.buffer;
		String.resetBuffer;
	}