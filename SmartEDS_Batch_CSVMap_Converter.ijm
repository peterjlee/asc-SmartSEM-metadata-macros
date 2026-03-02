/*
	This macro converts a SmartEDS CSV map (and all other in the same directory) into a 32-bit image with embedded scale and metadata in the ImageJ TIF header.
	v230329: 1st version  Peter J. Lee   3/29/2023 5:39 PM
	v230410: Output image size now full. Overwrite check fixed. Added manual field width input (but AR may still not match SEM).
	v230411-2: Allows for asymmetrical pixels. Allows scale check skipping after first value. Can pull true dimensions off active image. Adds range to metaData and log.
	v230420: Longer explanation message on image scale. F1: updated indexOf functions. F2-3: updated safeSaveAndClose.
	v240208: Adds an option to also output a csv file the has the coordinates as rows and columns as x and y coordinates respectively and the values in a single column.
	v240208b-c: Changed macro name to reflect new functionality. Fixed unbalanced bracket (now much faster ;-) ). You can now specify a different output directory. Closing saved images now works.
	v240305: Adds new scaling and debug options.
	v240306: Adds color phase map option. Filename prefix option added.
	v240315: Adds defaults exclusions for phasemaps based on csv names. Corrected order of main dialog.
	v240423-4: Legend width auto adjusts. Common set name can be replaced. Phasemaps exclude "view"s by default.
	v240718: Took out addDirectory third option that require 1.54i.
 */
	macro "SmartEDS CSVMap to Data Image and/or 3 column csv" {
		macroL = "SmartEDS_CSVMap_Converter_v240718_f1.ijm";
		fS = File.separator;
		um = getInfo("micrometer.abbreviation");
		xChar = fromCharCode(0x00D7);
		mapPath = File.openDialog(macroL + ": Choose SmartEDS CSV file \(all other csv files will also be converted\)");
		if (!endsWith(toLowerCase(mapPath), ".csv")) mapPath = File.openDialog(macroL + ": File did not have csv extension, try again . . . ");
		filePath = File.getParent(mapPath);
		fileList = getFileList(filePath);
		if (!endsWith(filePath, fS)) filePath += fS;
		/* ASC message theme */
		infoColor = "#006db0"; /* Honolulu blue */
		instructionColor = "#798541"; /* green_dark_modern (121,133,65) AKA Wasabi */
		infoWarningColor = "#ff69b4"; /* pink_modern AKA hot pink */
		infoFontSize = 12;
		csvFilesAll = newArray();
		for (i=0; i<fileList.length; i++){
			if (endsWith(fileList[i], ".csv"))	csvFilesAll = Array.concat(csvFilesAll, fileList[i]);
		}
		mapStrings = newArray();
		csvFiles = newArray();
		for (i=0, c=0; i<csvFilesAll.length; i++){
			mapString = File.openAsString(filePath + csvFilesAll[i]);
			if (indexOf(mapString, "Matrix:")>0 && indexOf(mapString, ".spd")>0 && indexOf(mapString, "FieldWidth")>0){
				mapStrings[c] = mapString;
				csvFiles[c] = csvFilesAll[i];
				c++;
			}
		}
		csvN = csvFiles.length;
		csvNames = newArray();
		for (i=0; i<csvN; i++) csvNames[i] = replace(csvFiles[i], ".csv", "");
		IJ.log(csvN + " csv files found in " + filePath + " being converted to 32-bit TIF in the same folder");
		/* Now find any commonality in the names of the files to determine the set name */
		for (i=1, minCNL=csvNames[0].length; i<csvN; i++) minCNL = minOf(minCNL, csvNames[i].length); /* Determine the minimum name length */
		for (i=1, isCommon=true; i<minCNL-1 && isCommon; i++){
			commonName = substring(csvNames[0], 0, i+1);
			for (j=0; j<csvN-1 && isCommon; j++)
				if (commonName!=substring(csvNames[j+1], 0, i+1)) isCommon = false;
		}
		commonName = substring(commonName, 0, commonName.length-1);
		if (nImages>0){
			getPixelSize(imageUnit, imagePixelWidth, imagePixelHeight);
			imageWidthActive = Image.width;
			imageFieldWidth = imageWidthActive * imagePixelWidth;
			imageHeightActive = Image.height;
			imageFieldHeight = imageHeightActive * imagePixelHeight;
			imageTitle = getTitle();
		}
		for (f=0, scaleSkip=false; f<csvN; f++){
			mapPath = filePath + csvFiles[f];
			if (indexOf(mapStrings[f], "Matrix:")>0 && indexOf(mapStrings[f], ".spd")>0 && indexOf(mapStrings[f], "FieldWidth")>0){
				mapLines = split(mapStrings[f],"\n");
				mapLineN = lengthOf(mapLines);
				parameters = newArray();
				metaInfo = "";
				allMapLines = "Map lines:";
				for(i=0;i<mapLineN; i++){
					if (mapLines[i]=="") i = mapLineN;
					else {
						allMapLines += "\n" + mapLines[i];
						morePs = split(mapLines[i],",");
						parameters = Array.concat(parameters,morePs);
						metaInfo += mapLines[i] + ",";
					}
				}
				if(endsWith(metaInfo,",")) metaInfo = substring(metaInfo,0,metaInfo.length-1);
				metaInfo = replace(metaInfo,", ,","\n");
				metaInfo = replace(metaInfo,",\t\t,","\n");
				metaInfo = replace(metaInfo,":,",":");
				metaInfo = replace(metaInfo,",-", "\n-");
				iMatrix = indexOfArrayThatStartsWith(parameters, "Matrix", -1) + 1;
				iFieldWidth = indexOfArrayThatStartsWith(parameters, "FieldWidth", -1) + 1;
				iMatrixStart = indexOfArrayThatStartsWith(mapLines, "X/Y", -1) + 1;
				if (iFieldWidth>0 && iMatrix>0 && iMatrixStart>0){
					matrix = parameters[iMatrix];
					pxDims = split(matrix," x ");
					matrixWidthPx = parseInt(pxDims[0]);
					matrixHeightPx = parseInt(pxDims[1]);
					matrixWidth_mm = parseFloat(parameters[iFieldWidth]);
					if (scaleSkip==true){
						if (matrixWidth_mm * 1000==matrixWidth_um) scaleSkip==false;
					}
					if (scaleSkip==false){
						matrixWidth_um = 1000 * matrixWidth_mm;
						matrixHeight_um = matrixHeightPx * matrixWidth_um / matrixWidthPx;
						if (f==0) Dialog.create("General options: " + macroL);
						else Dialog.create("Correct scale: " + macroL);
							Dialog.addMessage("The matrix width in the CSV header may not match the true scale if the SEM magnification is not set to \n           the screen mag \(i.e. not Polaroid\)", infoFontSize, infoWarningColor);
							Dialog.addNumber("Field width", matrixWidth_um, 3, 7, um + " \(default is from csv header\)");
							Dialog.addNumber("Field height", matrixHeight_um, 3, 7, um + " \(default is calculated from frame AR\)");
							if (nImages>0){
								Dialog.addMessage("Active image: " + imageTitle + "\nhas a width of " + imageFieldWidth + " " + imageUnit + ", and a height of " + imageFieldHeight + " " + imageUnit, infoFontSize, infoColor);
								Dialog.addCheckbox("Override with active image matrix width and height?", true);
							}
							if (f==0){
								Dialog.addCheckbox("Use the same scale for the rest of the \(" + csvN-f + "\) images if they have the same FW?",true);
								Dialog.addDirectory("Output directory", filePath); /* removed character limit option that required 1.54i */
								Dialog.addString("Create sub-directory \(leave blank if not desired\):", "extracted", minOf(screenWidth-50, lengthOf(csvNames[f])+10));
								Dialog.addString("Add file prefix", "", 40);
								if (commonName.length>0){
									Dialog.addString("Replace common name", commonName, 40);
									Dialog.setInsets(0, 50, 5);
									Dialog.addMessage("Text ''" + commonName + "'' is common to all " + csvN + " files in the set and will be replaced with text entered above", infoFontSize, infoColor);
								}
								Dialog.addCheckbox("Stretch contrast \(zero clipping\)?", true);
								Dialog.addCheckbox("If pixels are aspected also create a square-pixel copy of the image", false);
								if (nImages>0) Dialog.addCheckbox("Create a copy with the same dimensions as the active image", false);
								scalingOptions = newArray("None", "Bilinear", "Bicubic");
								Dialog.addRadioButtonGroup("Scaling interpolation:", scalingOptions,1,3,"None");
								scaleF = round(1280 / (matrixWidthPx + matrixHeightPx));
								if (scaleF<=1) scaleF = NaN;
								Dialog.addNumber("Create pixelated magnified copy", scaleF, 0, 3, xChar + " factor \(integer magnification applied to " + matrixWidthPx + " " + xChar + " " + matrixHeightPx + "\)");
								miscOptions = newArray("Close new image after successful save?", "Create new CSV files with x, y, and value columns?", "Create color phase map", "Diagnostic output");
								miscChecks = newArray(true, true, true, false);
								Dialog.setInsets(0, 20, 0);
								Dialog.addCheckboxGroup(2, 2, miscOptions, miscChecks);
								excelMaxRows = 1048576 - 12; /* max rows available with header */
								if ((matrixWidthPx * matrixHeightPx)>(excelMaxRows)) Dialog.addMessage("Note that only the first " + matrixWidthPx * matrixHeightPx + "rows will be saved in the x, y, v file", infoFontSize, infoWarningColor);
							}
						Dialog.show();
							matrixWidth_um = Dialog.getNumber();
							matrixHeight_um = Dialog.getNumber();
							if (nImages>0) useImageScale = Dialog.getCheckbox();
							else useImageScale = false;
							if (f==0){
								scaleSkip = Dialog.getCheckbox();
								outPath = Dialog.getString;
								if (!endsWith(outPath, fS)) outPath += fS;
								subDir = Dialog.getString();
								if (subDir!= ""){
									outPath += subDir + fS;
									if (!endsWith(outPath, fS)) saveDir += fS;
								}
								if (outPath!=filePath){
									isFile = File.isFile(outPath);
									isDir = File.isDirectory(outPath);
									if (!isDir && !isFile) File.makeDirectory(outPath);
									else if (isFile && !isDir) exit("Selected output directory is a file");
								}		
								prefix = Dialog.getString;
								commonReplace = false;
								if (commonName.length>0){
									commonReplacement = Dialog.getString;
									if (commonReplacement!=commonName) commonReplace = true;
								}
								stretchContrast = Dialog.getCheckbox();
								sqPixelSave = Dialog.getCheckbox();
								if (nImages>0) scaleToActive = Dialog.getCheckbox();
								else scaleToActive = false;
								interp = Dialog.getRadioButton();
								scaleF = Dialog.getNumber();
								if (!isNaN(scaleF)) scaleF = round(scaleF);
								closeGeneratedImage =  Dialog.getCheckbox();
								coordCols = Dialog.getCheckbox();
								phaseMap = Dialog.getCheckbox();
								diagnostic = Dialog.getCheckbox();
							}
						if (f==0 && phaseMap){
							elementColors = newArray();
							Dialog.create("Phase map options \(" + macroL + "\)");
								colorChoicesStd = newArray("red", "green", "blue", "cyan", "magenta", "yellow", "pink", "orange", "violet");
								colorChoicesMaterials = newArray("bronze", "antique_bronze", "brass", "dull_brass", "chrome", "copper", "aged_copper", "dusky_copper", "light_copper", "garnet", "burnished_gold", "gold", "slate_gray", "titanium", "vault_garnet", "plaza_brick", "vault_gold");
								colorChoicesMod = newArray("aqua_modern", "blue_accent_modern", "blue_dark_modern", "blue_modern", "blue_honolulu", "gray_modern", "green_dark_modern", "green_modern", "green_modern_accent", "green_spring_accent", "orange_modern", "pink_modern", "purple_modern", "red_n_modern", "red_modern", "tan_modern", "violet_modern", "yellow_modern");
								colorChoicesNeon = newArray("jazzberry_jam", "radical_red", "wild_watermelon", "outrageous_orange", "supernova_orange", "atomic_tangerine", "neon_carrot", "sunglow", "laser_lemon", "electric_lime", "screamin'_green", "magic_mint", "blizzard_blue", "dodger_blue", "shocking_pink", "razzle_dazzle_rose", "hot_magenta");
								grayChoices = newArray("light_gray", "gray", "dark_gray");
								colorChoices = Array.concat("none", colorChoicesStd, colorChoicesMaterials, colorChoicesMod, colorChoicesNeon);
								Dialog.addMessage("Choose 'none' \(top of list\) if it should not be included in the map", infoFontSize, instructionColor);
								for (p=0, pColors=1; p<csvN; p++){
									tLC = toLowerCase(csvNames[p]);
									if (indexOf(tLC, "image")>=0 || indexOf(tLC, "cps")>=0 || indexOf(tLC, "view")>=0){
										Dialog.addChoice(p + 1 + ". Color for " + csvNames[p], Array.concat("none", grayChoices, colorChoicesStd, colorChoicesMod, colorChoicesNeon), "none");
										// Dialog.setInsets(0, 100, 5);
										// Dialog.addNumber("Percent of 65535 intensity for " + p + 1, 20, 0, 3, "%");
									}
									else {
										Dialog.addChoice(p + 1 + ". Color for " + csvNames[p], colorChoices, colorChoices[pColors]);
										pColors++;
									}
								}
								Dialog.addCheckbox("Create Legend____________________________", true);
								if (!isNaN(scaleF)) Dialog.addCheckbox("Create legend for enlarged map", true);
								fontNameChoice = getFontChoiceList();
								iFN = indexOfArray(fontNameChoice, call("ij.Prefs.get", "asc.legend.font", fontNameChoice[0]), 0);
								Dialog.addChoice("Legend font:", fontNameChoice, fontNameChoice[iFN]);
								if (commonName.length>0) defStringRep = commonName  + "^";
								else  defStringRep = "_^: ";
								Dialog.addString("Replace string in legend 1 \(string'^'replacement\)", defStringRep, defStringRep.length + 5);
								Dialog.addString("Replace string in legend 2 \(string'^'replacement\)", "", defStringRep.length + 5);
								Dialog.setInsets(0, 150, 0);
								Dialog.addMessage("To delete the text string do not add any text after '^'", infoFontSize, instructionColor);
							Dialog.show();
								pMSuffix = "";
								iFactors = newArray(csvN);
								iFactors = Array.fill(iFactors, 1);
								for (p=0, elementN=0; p<csvN; p++){
									elementColors[p] = Dialog.getChoice();
									// if (indexOf(tLC, "image")>=0 || indexOf(tLC, "cps")>=0 || indexOf(tLC, "view")>=0)
										// iFactors[p] = Dialog.getNumber() / 65535;
									if (elementColors[p]!="none"){
										pMSuffix += "_" + replace(csvNames[p], commonName, "") + "-" + elementColors[p];
										elementN++;
									}
								}
								makeLegend = Dialog.getCheckbox();
								if (!isNaN(scaleF)) makeScaleFLegend = Dialog.getCheckbox();
								else makeScaleFLegend = false;
								fontName = Dialog.getChoice();
								replaces1 = split(Dialog.getString(), "^");
								if (replaces1.length==1) replaces1 = Array.concat(replaces1, ""); /* To handle replace with nothing */
								replaces2 = split(Dialog.getString(), "^");
								if (replaces2.length==1) replaces2 = Array.concat(replaces2, ""); /* To handle replace with nothing */
							setBatchMode(true);
							call("ij.Prefs.set", "asc.legend.font", fontName);
							if (elementN<1) phaseMap = false;
							if (phaseMap){
								phaseMapName = prefix + "phaseMap" + pMSuffix;
								newImage(phaseMapName, "16-bit black", matrixWidthPx, matrixHeightPx, 3);
							}
						}
					}
					if (diagnostic) IJ.log(allMapLines);
					newImageFilename = prefix + csvNames[f] + "_32bit";
					if (commonReplace) newImageFilename = replace(newImageFilename, commonName, commonReplacement);
					if (useImageScale){
						newImageFilename += "_scaleOverride";
						pixelWidth = imageFieldWidth / matrixWidthPx;
						pixelHeight = imageFieldHeight / matrixHeightPx;
					}
					else {
						pixelWidth = matrixWidth_um / matrixWidthPx;
						pixelHeight = matrixHeight_um / matrixHeightPx;
					}
					pixAR = pixelHeight/pixelWidth;
					if (pixAR>1.001 || pixAR<0.999) newImageFilename += "_PxAR-"+d2s(pixAR,3);
					else sqPixelSave = false;
					if (stretchContrast) newImageFilename += "_str";
					newImage(newImageFilename, "32-bit black", matrixWidthPx, matrixHeightPx, 1);
					String.resetBuffer;
					for (row=0; row<matrixWidthPx; row++){
						showStatus("Creating " + newImageFilename);
						showProgress(row, matrixWidthPx);
						cols = split(mapLines[iMatrixStart + row], ",");
						for (col=0, minVal=9E99, maxVal=0; col<matrixHeightPx; col++){
							inputVal = parseFloat(cols[col + 1]);
							minVal = minOf(minVal, inputVal);
							maxVal = maxOf(maxVal, inputVal);
							setPixel(row, col, parseFloat(inputVal));
							if (phaseMap && (elementColors[f]!="none") ){
								rgbs = getColorArrayFromColorName(elementColors[f]);
								selectImage(phaseMapName);
								for (r=0; r<3; r++){
									setSlice(r + 1);
									setPixel(row, col, getPixel(row, col) + round(iFactors[f] * rgbs[r] * parseFloat(inputVal)));
								}
								selectImage(newImageFilename);
							}
							if (coordCols)
								String.append(row * pixelWidth + "," + col * pixelHeight + "," + inputVal + "\n");
						}
					}
					if (coordCols){
						metaHeader = replace(metaInfo, " :", ",");
						metaHeader = replace(metaHeader, ": ", ",");
						metaHeader = replace(metaHeader, "Matrix:", "Matrix");
						while (indexOf(metaHeader, " ,")>=0) metaHeader = replace(metaHeader, " ,", ",");
						while (indexOf(metaHeader, ", ")>=0) metaHeader = replace(metaHeader, ", ", ",");
						metaHeader = replace(metaHeader, ",\n", "\n");
						metaHeader = replace(metaHeader, ",,", ",");
						metaHeader += "\n\nx \("+um+"\), y \("+um+"\), " + csvNames[f] + "\n";
						newCSVFilename = prefix + csvNames[f] + "_coordCols.csv";
						if (commonReplace) newCSVFilename = replace(newCSVFilename, commonName, commonReplacement);
						coordColsPath = outPath + newCSVFilename; /* restore file separator for imageJ saves */
						if (File.exists(coordColsPath)){
							overwrite = getBoolean(coordColsPath + " already exists; overwrite file?");
							if (overwrite) File.saveString(metaHeader + String.buffer, coordColsPath);
						}
						else File.saveString(metaHeader + String.buffer, coordColsPath);
						String.resetBuffer;
					}
					logOutput = "\nRange: " + minVal + " - " + maxVal;
					if (useImageScale){
						setVoxelSize(pixelWidth, pixelHeight, 1, imageUnit);
						logOutput += "\nField Width Applied: " + imageFieldWidth;
						logOutput += "\nField Height Applied: " + imageFieldHeight;
					}
					else setVoxelSize(pixelWidth, pixelHeight, 1, um);
					if (stretchContrast){
						run("Enhance Contrast...", "saturated=0");
						logOutput += "\nContrast stretch \(linear\), saturation = zero";
					}
					metaInfo += logOutput;
					setMetadata("Info", metaInfo);
					savePath = outPath + newImageFilename + ".tif";
					saveAs("Tiff", savePath);
					mapID = getImageID();
					if (sqPixelSave){
						if (pixAR>1.001) matrixWidthPx /= pixAR;
						else matrixHeightPx /= pixAR;
						sqFilename = newImageFilename + "_sqPx\("+interp+"\)";
						run("Scale...", "x=- y=- width=" + matrixWidthPx + " height=" + matrixHeightPx + " interpolation=" + interp + " average create title=&sqFilename");
						safeSaveAndClose("Tiff", outPath, sqFilename + ".tif", true);
					}
					if (scaleToActive){
						scaledFilename = newImageFilename + "_scaled\(" + interp + "\)";
						run("Scale...", "x=- y=- width=" + imageWidthActive + " height=" + imageHeightActive + " interpolation=" + interp + " average create title=" + scaledFilename);
						safeSaveAndClose("Tiff", outPath, scaledFilename + ".tif", true);
					}
					if (!isNaN(scaleF)){
						run("Scale...", "x=" + scaleF + " y=" + scaleF + " interpolation=None average create");
						scaleFFilename = newImageFilename + "_scaled\(x" + scaleF + "\)";
						safeSaveAndClose("Tiff", outPath, scaleFFilename + ".tif", true);
					}
					if (File.exists(savePath)){
						IJ.log("Converted map file:\n" + outPath + logOutput + "\n___________");
						if (closeGeneratedImage && isOpen(newImageFilename + ".tif")) close(newImageFilename + ".tif");
					}
				}
			}
		}
		if (phaseMap){
			selectImage(phaseMapName);
			run("Enhance Contrast...", "saturated=0 normalize process_all use");
			// run("16-bit");
			run("Stack to RGB");
			rgbPhaseMapName = getTitle() + ".tif";
			rgbPhaseMapWith = Image.width;
			safeSaveAndClose("Tiff", outPath, rgbPhaseMapName, false);
			closeImageByTitle(phaseMapName);
			if (scaleToActive){
				scaledPhaseMap = phaseMapName + "_scaled\(" + interp + "\)";
				run("Scale...", "x=- y=- width=" + imageWidthActive + " height=" + imageHeightActive + " interpolation=" + interp + " average create title=" + scaledPhaseMap);
				safeSaveAndClose("Tiff", outPath, scaledPhaseMap + ".tif", true);
			}
			if (!isNaN(scaleF)){
				selectImage(rgbPhaseMapName);
				run("Scale...", "x=" + scaleF + " y=" + scaleF + " interpolation=None average create");
				scaleFPhaseMap = phaseMapName + "_scaled\(x" + scaleF + "\)";
				safeSaveAndClose("Tiff", outPath, scaleFPhaseMap + ".tif", true);
			}
			orFGC = getValue("color.foreground");
			if (makeLegend || makeScaleFLegend){
				showStatus("Created Phase Map legend");
				legendFs = newArray();
				if (makeLegend) legendFs = Array.concat(legendFs, ((matrixHeightPx - 8)/ elementN) - 1);
				if (makeScaleFLegend) legendFs = Array.concat(legendFs, minOf(48, ((matrixHeightPx * scaleF - 8)/ elementN) - 1));
				if (nImages==0) open(outPath + rgbPhaseMapName);
				for (i=0; i<legendFs.length; i++){
					setFont(fontName, legendFs[i]);
					fontHeight = getValue("font.height");
					margin = round(fontHeight/3);
					symbolWidth =  fontHeight - margin; /* keep same symbol width */
					legendH = round(fontHeight * csvN + 2 + margin);
					legendT = phaseMapName + "_legend-" + legendH;
					newImage(legendT, "RGB white", Image.width, legendH, 1);
					for (s=0, c=0, stringMax=0; s<csvN; s++){
						if (elementColors[s]!="none"){
							setColor("black");
							legendText = csvNames[s];
							if (replaces1.length>1){
								legendText = replace(legendText, replaces1[0], replaces1[1]);
								if (replaces2.length>1)
									legendText = replace(legendText, replaces2[0], replaces2[1]);
							}
							stringMax = maxOf(stringMax, getStringWidth(legendText));
							if (stringMax + margin * 15 > Image.width)
								run("Canvas Size...", "width=" + stringMax + margin * 15 + " height=" + Image.height + " position=Center-Left");
							drawString(legendText, margin * 5, margin /2 + fontHeight * (c + 1));
							stringMax = maxOf(stringMax, getStringWidth(legendText));
							rgbs = getColorArrayFromColorName(elementColors[s]);
							setColor(rgbs[0], rgbs[1], rgbs[2]);
							fillRect(margin, margin + fontHeight * c, symbolWidth, fontHeight - margin);
							c++;
						}
					}
					run("Select Bounding Box (guess background color)");
					run("Enlarge...", "enlarge=&margin pixel");
					run("Crop");
					legendT = replace(rgbPhaseMapName + "_legend-" + Image.width + xChar + Image.height + ".png", ".tif", "");
					saveAs("PNG", outPath + legendT);
					closeImageByTitle(legendT);
				}
				setColor(orFGC);
				closeImageByTitle(rgbPhaseMapName);
			}
		}
		setBatchMode("exit & display");
		showStatus("!completed: " + macroL, "flash green");
	}
/*
	( 8(|)	( 8(|)	ASC Functions	@@@@@:-)	@@@@@:-)
*/
	function closeImageByTitle(windowTitle) {  /* Cannot be used with tables */
		/* v181002: reselects original image at end if open
		   v200925: uses "while" instead of if so it can also remove duplicates
		   v230411:	checks to see if any images opn first.
		*/
		if(nImages>0){
			oIID = getImageID();
			while (isOpen(windowTitle)) {
				selectWindow(windowTitle);
				close();
			}
			if (isOpen(oIID)) selectImage(oIID);
		}
	}
  	function getFontChoiceList() {
		/*	v180723 first version
			v180828 Changed order of favorites. v190108 Longer list of favorites. v230209 Minor optimization.
			v230919 You can add a list of fonts that do not produce good results with the macro. 230921 more exclusions. v240306: Restored SansSerif.
		*/
		systemFonts = getFontList();
		IJFonts = newArray("SansSerif", "Serif", "Monospaced");
		fontNameChoices = Array.concat(IJFonts, systemFonts);
		blackFonts = Array.filter(fontNameChoices, "([A-Za-z] + .*[bB]l.*k)");
		eBFonts = Array.filter(fontNameChoices, "([A-Za-z] + .*[Ee]xtra.*[Bb]old)");
		uBFonts = Array.filter(fontNameChoices, "([A-Za-z] + .*[Uu]ltra.*[Bb]old)");
		fontNameChoices = Array.concat(blackFonts, eBFonts, uBFonts, fontNameChoices); /* 'Black' and Extra and Extra Bold fonts work best */
		faveFontList = newArray("Your favorite fonts here", "Arial Black", "Myriad Pro Black", "Myriad Pro Black Cond", "Noto Sans Blk", "Noto Sans Disp Cond Blk", "Open Sans ExtraBold", "Roboto Black", "Alegreya Black", "Alegreya Sans Black", "Tahoma Bold", "Calibri Bold", "Helvetica", "SansSerif", "Calibri", "Roboto", "Tahoma", "Times New Roman Bold", "Times Bold", "Goldman Sans Black", "Goldman Sans", "SansSerif", "Serif");
		/* Some fonts or font families don't work well with ASC macros, typically they do not support all useful symbols, they can be excluded here using the .* regular expression */
		offFontList = newArray("Alegreya SC Black", "Archivo.*", "Arial Rounded.*", "Bodon.*", "Cooper.*", "Eras.*", "Fira.*", "Gill Sans.*", "Lato.*", "Libre.*", "Lucida.*", "Merriweather.*", "Montserrat.*", "Nunito.*", "Olympia.*", "Poppins.*", "Rockwell.*", "Tw Cen.*", "Wingdings.*", "ZWAdobe.*"); /* These don't work so well. Use a ".*" to remove families */
		faveFontListCheck = newArray(faveFontList.length);
		for (i=0, counter=0; i<faveFontList.length; i++) {
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
				if (endsWith(offFontList[j], ".*")){
					if (startsWith(fontNameChoices[i], substring(offFontList[j], 0, indexOf(offFontList[j], ".*")))){
						fontNameChoices = Array.deleteIndex(fontNameChoices, i);
						i = maxOf(0, i-1);
					}
					// fontNameChoices = Array.filter(fontNameChoices, "(^" + offFontList[j] + ")"); /* RegEx not working and very slow */
				}
			}
		}
		fontNameChoices = Array.concat(faveFontListCheck, fontNameChoices);
		for (i=0; i<fontNameChoices.length; i++) {
			for (j=i + 1; j<fontNameChoices.length; j++)
				if (fontNameChoices[i]==fontNameChoices[j]) fontNameChoices = Array.deleteIndex(fontNameChoices, j);
		}
		return fontNameChoices;
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
	function safeSaveAndClose(filetype, path, fileSaveName, closeImageIfSaved){
		/* v230411: 1st version reworked
			v230812: Uses full dialog which should save time for non-saves, includes options to change the directory and filetype.
			v230814: Close by imageID not filename. Added option to override closeImageIfSaved.
			v230915: Saves if there is no change in path rather than getting stuck in loop.
			v230920: Allows empty path string.
			v240315: Fixed RadioButton issue.
		*/
		functionL = "safeSaveAndClose_v240315";
		imageID = getImageID();
		fS = File.separator;
		filetypes = newArray("tiff", "png", "jpeg");
		extensions = newArray("tif", "png", "jpg");
		for (i=0; i<3; i++){
			if (filetype==filetypes[i]) extension = extensions[i];
			else extension = extensions[0];
		}
		if (!endsWith(fileSaveName, extension)){
			if (lastIndexOf(fileSaveName, ".")>fileSaveName.length-5) fileSaveName = substring(fileSaveName, 0, lastIndexOf(fileSaveName, ".")+1) + extension;
			else fileSaveName += "." + extension;
		}
		if (path!=""){
			if(endsWith(path, fS)) path = substring(path, 0, path.length-1);
			fullPath = path + fS + fileSaveName;
		}
		else fullPath = "";
		newSave = false;
		if (!File.exists(fullPath) && fullPath!=""){
			saveAs(filetype, fullPath);
			if (File.exists(fullPath)) newSave = true;
		}
		if (!newSave){
			Dialog.create("Options: " + functionL);
				if (path!=""){
					Dialog.addMessage("File: " + fileSaveName + " already exists in\n" + path);
					Dialog.addMessage("If no changes are made below, the existing file will be overwritten");
				}
				Dialog.addString("Change the filename?", fileSaveName, fileSaveName.length+5);
				if (path=="") path = File.directory;
				Dialog.addDirectory("Change the directory?", path);
				// Dialog.addChoice("Change the filetype?", filetypes, filetypes[0]);
				Dialog.addRadioButtonGroup("Change the filetype?", filetypes, 1, filetypes.length, filetypes[0]);
				Dialog.addCheckbox("Don't save file", false);
				Dialog.addCheckbox("Close image \(imageID: " + imageID + ") after successful save", closeImageIfSaved);
			Dialog.show;
				newFileSaveName = Dialog.getString();
				newPath = Dialog.getString();
				// newFiletype = Dialog.getChoice();
				newFiletype = Dialog.getRadioButton();
				dontSaveFile = Dialog.getCheckbox();
				closeImageIfSaved = Dialog.getCheckbox();
			if (!dontSaveFile){
				if (!File.isDirectory(newPath)) File.makeDirectory(newPath);
				if (!endsWith(newPath, fS)) newPath += fS;
				for (i=0; i<3; i++){
					if (newFiletype==filetypes[i]){
						newExtension = extensions[i];
						if (extension!=newExtension) newfileSaveName = replace(newFileSaveName, extension, newExtension);
					}
				}
				newFullPath = newPath + newFileSaveName;
				if (!File.exists(newFullPath) || newFullPath==fullPath) saveAs(newFiletype, newFullPath);
				else safeSaveAndClose(newFiletype, newPath, newFileSaveName, closeImageIfSaved);
				if (File.exists(newFullPath)) newSave = true;
			}
		}
		if (newSave && closeImageIfSaved && nImages>0){
			if (getImageID()==imageID) close();
			else IJ.log(functionL + ": Image ID change so fused image not closed");
		}
	}
/*
	Color Functions
	*/
		function getColorArrayFromColorName(colorName) {
		/* v180828 added Fluorescent Colors
		   v181017-8 added off-white and off-black for use in gif transparency and also added safe exit if no color match found
		   v191211 added Cyan
		   v211022 all names lower-case, all spaces to underscores v220225 Added more hash value comments as a reference v220706 restores missing magenta
		   v230130 Added more descriptions and modified order.
		   v230908: Returns "white" array if not match is found and logs issues without exiting.
		   v240123: Removed duplicate entries: Now 53 unique colors.
		   v240709: Added 2024 FSU-Branding Colors. Some reorganization. Now 60 unique colors.
		   v260202: Added 12 (mostly metallic) "Materials" colors. Now 72 unique colors.
		*/
		functionL = "getColorArrayFromColorName_v260203";
		cA = newArray(255, 255, 255); /* defaults to white */
		if (colorName == "white") cA = newArray(255, 255, 255);
		else if (colorName == "black") cA = newArray(0, 0, 0);
		else if (colorName == "off-white") cA = newArray(245, 245, 245);
		else if (colorName == "off-black") cA = newArray(10, 10, 10);
		else if (colorName == "light_gray") cA = newArray(200, 200, 200);
		else if (colorName == "gray") cA = newArray(127, 127, 127);
		else if (colorName == "dark_gray") cA = newArray(51, 51, 51);
		else if (colorName == "red") cA = newArray(255, 0, 0);
		else if (colorName == "green") cA = newArray(0, 255, 0);						/* #00FF00 AKA Lime green */
		else if (colorName == "blue") cA = newArray(0, 0, 255);
		else if (colorName == "cyan") cA = newArray(0, 255, 255);
		else if (colorName == "yellow") cA = newArray(255, 255, 0);
		else if (colorName == "magenta") cA = newArray(255, 0, 255);					/* #FF00FF */
		else if (colorName == "pink") cA = newArray(255, 192, 203);
		else if (colorName == "violet") cA = newArray(127, 0, 255);
		else if (colorName == "orange") cA = newArray(255, 165, 0);
			/* Excel Modern  + */
		else if (colorName == "aqua_modern") cA = newArray(75, 172, 198);			/* #4bacc6 AKA "Viking" aqua */
		else if (colorName == "blue_accent_modern") cA = newArray(79, 129, 189);	/* #4f81bd */
		else if (colorName == "blue_dark_modern") cA = newArray(31, 73, 125);		/* #1F497D */
		else if (colorName == "blue_honolulu") cA = newArray(0, 118, 182);			/* Honolulu Blue #006db0 */
		else if (colorName == "blue_modern") cA = newArray(58, 93, 174);			/* #3a5dae */
		else if (colorName == "gray_modern") cA = newArray(83, 86, 90);				/* bright gray #53565A */
		else if (colorName == "green_dark_modern") cA = newArray(121, 133, 65);		/* Wasabi #798541 */
		else if (colorName == "green_modern") cA = newArray(155, 187, 89);			/* #9bbb59 AKA "Chelsea Cucumber" */
		else if (colorName == "green_modern_accent") cA = newArray(214, 228, 187); 	/* #D6E4BB AKA "Gin" */
		else if (colorName == "green_spring_accent") cA = newArray(0, 255, 102);	/* #00FF66 AKA "Spring Green" */
		else if (colorName == "orange_modern") cA = newArray(247, 150, 70);			/* #f79646 tan hide, light orange */
		else if (colorName == "pink_modern") cA = newArray(255, 105, 180);			/* hot pink #ff69b4 */
		else if (colorName == "purple_modern") cA = newArray(128, 100, 162);		/* blue-magenta, purple paradise #8064A2 */
		else if (colorName == "red_n_modern") cA = newArray(227, 24, 55);
		else if (colorName == "red_modern") cA = newArray(192, 80, 77);
		else if (colorName == "tan_modern") cA = newArray(238, 236, 225);
		else if (colorName == "violet_modern") cA = newArray(76, 65, 132);
		else if (colorName == "yellow_modern") cA = newArray(247, 238, 69);
			/* FSU */
		else if (colorName == "garnet") cA = newArray(120, 47, 64);					/* #782F40 */
		else if (colorName == "gold") cA = newArray(206, 184, 136);					/* #CEB888 */
		else if (colorName == "gulf_sands") cA = newArray(223, 209, 167);				/* #DFD1A7 */
		else if (colorName == "stadium_night") cA = newArray(16, 24, 32);				/* #101820 */
		else if (colorName == "westcott_water") cA = newArray(92, 184, 178);			/* #5CB8B2 */
		else if (colorName == "vault_garnet") cA = newArray(166, 25, 46);				/* #A6192E */
		else if (colorName == "legacy_blue") cA = newArray(66, 85, 99);				/* #425563 */
		else if (colorName == "plaza_brick") cA = newArray(66, 85, 99);				/* #572932 */
		else if (colorName == "vault_gold") cA = newArray(255, 199, 44);				/* #FFC72C */
			/* Materials */
		else if (colorName == "bronze") cA = newArray(205, 127, 50);					/* #CD7F32 */
		else if (colorName == "antique_bronze") cA = newArray(102, 93, 30);			/* #665D1E */
		else if (colorName == "brass") cA = newArray(181, 166, 66);					/* #B5A642 */
		else if (colorName == "dull_brass") cA = newArray(rgb(142, 124, 80);			/* #8E7C50 */
		else if (colorName == "burnished_gold") cA = newArray(rgb(133, 109, 77);		/* #856D4D */
		else if (colorName == "chrome") cA = newArray(229, 228, 226);					/* #E5E4E2 */
		else if (colorName == "copper") cA = newArray(184, 115, 51);					/* #B87333 */
		else if (colorName == "aged_copper") cA = newArray(110, 58, 7));				/* #6E3A07 */
		else if (colorName == "dusky_copper") cA = newArray(110, 59, 59);				/* #6E3B3B */
		else if (colorName == "light_copper") cA = newArray(218, 138, 103);			/* #DA8A67 */
		else if (colorName == "slate_gray") cA = newArray(112, 128, 144);				/* #708090 */
		else if (colorName == "titanium") cA = newArray(135, 134, 129);				/* #878681 */
		   /* Fluorescent Colors https://www.w3schools.com/colors/colors_crayola.asp   */
		else if (colorName == "radical_red") cA = newArray(255, 53, 94);			/* #FF355E */
		else if (colorName == "jazzberry_jam") cA = newArray(165, 11, 94);
		else if (colorName == "wild_watermelon") cA = newArray(253, 91, 120);		/* #FD5B78 */
		else if (colorName == "shocking_pink") cA = newArray(255, 110, 255);		/* #FF6EFF Ultra Pink */
		else if (colorName == "razzle_dazzle_rose") cA = newArray(238, 52, 210);	/* #EE34D2 */
		else if (colorName == "hot_magenta") cA = newArray(255, 0, 204);			/* #FF00CC AKA Purple Pizzazz */
		else if (colorName == "outrageous_orange") cA = newArray(255, 96, 55);		/* #FF6037 */
		else if (colorName == "supernova_orange") cA = newArray(255, 191, 63);		/* FFBF3F Supernova Neon Orange*/
		else if (colorName == "sunglow") cA = newArray(255, 204, 51);				/* #FFCC33 */
		else if (colorName == "neon_carrot") cA = newArray(255, 153, 51);			/* #FF9933 */
		else if (colorName == "atomic_tangerine") cA = newArray(255, 153, 102);		/* #FF9966 */
		else if (colorName == "laser_lemon") cA = newArray(255, 255, 102);			/* #FFFF66 "Unmellow Yellow" */
		else if (colorName == "electric_lime") cA = newArray(204, 255, 0);			/* #CCFF00 */
		else if (colorName == "screamin'_green") cA = newArray(102, 255, 102);		/* #66FF66 */
		else if (colorName == "magic_mint") cA = newArray(170, 240, 209);			/* #AAF0D1 */
		else if (colorName == "blizzard_blue") cA = newArray(80, 191, 230);		/* #50BFE6 Malibu */
		else if (colorName == "dodger_blue") cA = newArray(9, 159, 255);			/* #099FFF Dodger Neon Blue */
		else IJ.log(colorName + " not found in " + functionL + ": Color defaulted to white");
		return cA;
	}