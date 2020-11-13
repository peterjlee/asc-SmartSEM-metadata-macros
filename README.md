# asc-SmartSEM-metadata-macros
<p>These ImageJ macros use the <a href="https://imagej.nih.gov/ij/plugins/tiff-tags.html">tiff_tags plugin written by Joachim Wesner</a> to extract the metadata from the TIFF file header of a Zeiss SEM image.</p>

<p><img src="/images/AnnotatedSmartSEMexample_1024w.jpg" alt="Touch count of each object." width="1024"  /></p>

<p>The annotator macro (illustrated above) allows you to overlay up to 26 operating parameters onto a copy of the image (it will also automatically add the operating parameters to the ImageJ info header so that the copy will retain this information). The macro can be easily modified to create a custom annotation bar containing your favorite parameters. The annotation list can include blank lines and user input. The available formats and optional colors are the same as the &quot;fancy labelling&quot; macros. The metadata-to-info macro will simply copy the embedded metadata to the ImageJ info header, allowing it to be saved with the image. The metadata-to-otherimage macro will copy the metadata to any other open image you select. The export macro will export the microscope parameters to a csv file in the same directory as the original image.</p>

<p><sub><sup>
 <strong>Legal Notice:</strong> <br />
These macros have been developed to demonstrate the power of the ImageJ macro language and we assume no responsibility whatsoever for its use by other parties, and make no guarantees, expressed or implied, about its quality, reliability, or any other characteristic. On the other hand we hope you do have fun with them without causing harm.
<br />
The macros are continually being tweaked and new features and options are frequently added, meaning that not all of these are fully tested. Please contact me if you have any problems, questions or requests for new modifications.
 </sup></sub>
</p>
