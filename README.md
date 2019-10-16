# Marine Semantic Segmentation Training Dataset (MaSTr1325)
MaSTr1325 is a new large-scale marine semantic segmentation training dataset tailored for development of obstacle detection methods in small-sized coastal USVs. The dataset contains 1325 diverse images captured over a two year span with a real USV, covering a range of realistic conditions encountered in a coastal surveillance task. All images are per-pixel semantically labeled and synchronized with inertial measurements of the on-board sensors. In addition, a dataset augmentation protocol is proposed to address slight appearance differences of the images in the training set and those in deployment.

Each image from the dataset was manually annotated by human annotators with three categories (sea, sky and environment). An image editing software supporting multiple layers per image was used and each semantic region was annotated in a separate layer by multiple sized brushes for speed and accuracy. All annotations were carried out by in-house annotators and were verified and corrected by an expert to ensure a high-grade per-pixel annotation quality. The annotation procedure and the quality control took approximately twenty minutes per image. To account for the annotation uncertainty at the edge of semantically different regions, the edges between these regions were labeled by the unknown category. This label ensures that these pixels are excluded from learning.

Labels in ground-truth annotation masks correspond to the following values:
<ul>
	<li>
		Obstacles and environment = 0 (value zero)
	</li>
	<li>
		Water = 1 (value one)
	</li>
	<li>
		Sky = 2 (value two)
	</li>
	<li>
		Ignore region / unknown category = 4 (value four)
	</li>
</ul>

The dataset is publicly available for download:<br>
&darr; <a href="#">MaSTr1325 Images [512x384]</a><br>
&darr; <a href="#">MaSTr1325 Ground Truth Annotations [512x384]</a><br>
&darr; <a href="#">MaSTr1325 Images [1278x958]</a><br>
&darr; <a href="#">MaSTr1325 Ground Truth Annotations [1278x958]</a>

# Multi-modal Obstacle Detection Dataset 2 (MODD 2)
MODD2 is currently the biggest and the most challenging multi-modal marine obstacle detection dataset captured by a real USV. Diverse weather conditions (sunny, overcast, foggy), extreme situations (abrupt change of motion, sun gliter and reflections) and various small obstacles all contribute to its difficulty.

Each frame in the dataset was manually annotated by a human annotator and later verified by an expert. The edge of water is annotated by a polygon, while obstacles are outlined with bounding boxes. The annotated obstacles are further divided into two classes:
<ul>
	<li>large obstacles (whose bounding box straddles the sea edge) --- highlighted with cyan color,</li>
	<li>small obstacles (whose bounding box is fully located below the sea edge polygon) --- highlighted with light-red color.</li>
</ul>

The dataset is publicly available for download at:<br>
				&darr; <a href="http://box.vicos.si/borja/modd2_dataset/MODD2_video_data.zip">MODD2 Video Data and IMU Measurements</a><br>
				&darr; <a href="http://box.vicos.si/borja/modd2_dataset/MODD2_calibration_sequences.zip">MODD2 Calibration Sequences</a><br>
				&darr; <a href="http://box.vicos.si/borja/modd2_dataset/MODD2_annotations_v2.zip">MODD2 Ground Truth Annotations (for RAW images)</a><br>
				&darr; <a href="http://box.vicos.si/borja/modd2_dataset/MODD2_annotations_v2_rectified.zip">MODD2 Ground Truth Annotations (for rectified and undistorted images)</a><br>
				&darr; <a href="http://box.vicos.si/borja/modd2_dataset/MODD2_USVparts_masks.zip">MODD2 Masks of Visible Parts of the USV</a><br>
				
<b>Evaluation Scripts for Obstacle Detection in a Marine Environment</b>

We use performance measures inspired by Kristan et al. [1]. The accuracy of the sea-edge estimation is measured by mean-squared error and standard deviation over all sequences (denoted as &mu;<sub>edg</sub> and &sigma;<sub>edg</sub> respectively). The accuracy of obstacle detection is measured by number of true positives (TP), false positives (FP), false negatives (FN), and by F-measure.

To evaluate RMSE in water edge position, ground truth annotations were used in the following way. A polygon,  denoting the water surface was generated from water edge annotations. Areas, where large obstacles intersect the polygon, were removed. This way, a refined water edge was generated. For each pixel column in the full-sized image, a distance between water edge, as given by the ground truth and as determined by the algorithm, is calculated. These values are summarized into a single value by averaging across all columns, frames and sequences.

The evaluation of object detection follows the recommendations from PASCAL VOC challenges by Everingham et al. [2], with small, application-specific modification: detections above the annotated water edge are ignored and do not contribute towards the FP count as they do not affect the navigation of the USV. In certain situations a detection may oscillate between fully water-enclosed obstacle and the <i>dent</i> in the shoreline. In both cases, the obstacle is correctly segmented as non-water region and it can be successfully avoided. However, in first scenario the obstacle is explicitly detected, while second scenario provides us with only indirect detection. To address possible inaccuracies causing dents in the water-edge, the overlap between the dented region and obstacle is defined more strictly as that of water-enclosed obstacles. Note that the proposed treatment of detections is consistent with the problem of obstacle avoidance.

There are two evaluation scripts available:
<ul>
	<li>
		<i>modd2_evaluate_all_sequences_raw</i> - for evaluating the performance on raw and distorted images,
	</li>
	<li>
		<i>modd2_evaluate_all_sequences_undist</i> - for evaluating the performance on undistorted and rectified images.
	</li>
</ul>

Both evaluation scripts expect the same input parameters: a path to the MODD2 dataset root folder, a path to the folder where segmentation results are stored, a method name and a matrix of segmentation colors representing three labels (sky, obstacles and water). The folder containing segmentation results should be structured in the following way (an example for a method <i>"wasr_decoder_2"</i>):


The segmentation process should classify each pixel of an image in one of the three semantic categories:
<ol>
	<li>
		Sky
	</li>
	<li>
		Obstacles / Environment
	</li>
	<li>
		Water
	</li>
</ol>

Each semantic category is represented with its own color in a segmentation mask. For evaluation purposes we need to provide a 3x3 matrix of RGB values, where the first row of the matrix corresponds to the RGB encoding of the sky component, the second row corresponds to the RGB encoding of the obstacles/environment component and the third row corresponds to the RGB encoding of the water component.

An extensive evaluation of state-of-the-art segmentation methods is available on our website <a href="#">MODD 2 LeaderBoard</a>.

<b>Visualization Scripts</b>

<b>References:</b><br>
[1] <a href="https://ieeexplore.ieee.org/abstract/document/7073635">Kristan, Matej, et al. "Fast Image-Based Obstacle Detection from Unmanned Surface Vehicles."<br>
	IEEE Transactions on cybernetics 46.3 (2015): 641-654.</a><br>
[2] <a href="https://link.springer.com/article/10.1007/s11263-009-0275-4">Everingham, Mark, et al. "The Pascal Visual Object Classes (VOC) Challenge."<br>
	International Journal of Computer Vision 88.2 (2010): 303-338.</a>
