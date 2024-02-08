# asc-SmartSEM-metadata-macros
<p>These ImageJ macros use a variety of techniques to extract the metadata from SmartSEM images, the CZSEM_Metadata_To_Info and CZSEM_Transfer_MetadataToOtherImage macros use the <a href="https://imagej.nih.gov/ij/plugins/tiff-tags.html">tiff_tags plugin written by Joachim Wesner</a> to extract the data.</p>

<p><img src="/images/AnnotatedSmartSEMexample_1024w.jpg" alt="Annotated SmartSEM example." width="1024"  /></p>

<p>The annotator macro (illustrated above) allows you to overlay up to 40 operating parameters onto a copy of the image (it will also automatically add the operating parameters to the ImageJ info header so that the copy will retain this information). Alternatively you can expand the canvas to display the annotation outside the image. The main menu can be seen below. The macro can be easily modified to create a custom annotation bar containing your favorite parameters. The annotation list can include blank lines and user input. The available formats and optional colors are the same as the &quot;fancy labeling&quot; macros.</p>

<p><img src="/images/CZSEM_Annotator_and MetaDataExport_Menu1_PAL64_985x1045.png" alt="Menu1 for SmartSEM Annotator." width="512"  /></p>

<p>The metadata-to-info macro will simply copy the embedded metadata to the ImageJ info header, allowing it to be saved with the image. The metadata-to-otherimage macro will copy the metadata to any other open image you select. The export macro will export the microscope parameters to a csv file in the same directory as the original image.</p>

<p><sub><sup>
 <strong>Legal Notice:</strong> <br />
These macros have been developed to demonstrate the power of the ImageJ macro language and we assume no responsibility whatsoever for its use by other parties, and make no guarantees, expressed or implied, about its quality, reliability, or any other characteristic. On the other hand we hope you do have fun with them without causing harm.
<br />
The macros are continually being tweaked and new features and options are frequently added, meaning that not all of these are fully tested. Please contact me if you have any problems, questions or requests for new modifications.
 </sup></sub>
</p>
