# Multi-modal Obstacle Detection Dataset 2 (MODD 2)
Evaluation Scripts for Obstacle Detection in a Marine Environment

We use performance measures inspired by Kristan et al. [1]. The accuracy of the sea-edge estimation is measured by mean-squared error and standard deviation over all sequences (denoted as &mu;<sub>edg</sub> and &sigma;<sub>edg</sub> respectively). The accuracy of obstacle detection is measured by number of true positives (TP), false positives (FP), false negatives (FN), and by F-measure.

To evaluate RMSE in water edge position, ground truth annotations were used in the following way. A polygon,  denoting the water surface was generated from water edge annotations. Areas, where large obstacles intersect the polygon, were removed. This way, a refined water edge was generated. For each pixel column in the full-sized image, a distance between water edge, as given by the ground truth and as determined by the algorithm, is calculated. These values are summarized into a single value by averaging across all columns, frames and sequences.

The evaluation of object detection follows the recommendations from PASCAL VOC challenges by Everingham et al. [2], with small, application-specific modification: detections above the annotated water edge are ignored and do not contribute towards the FP count as they do not affect the navigation of the USV. In certain situations a detection may oscillate between fully water-enclosed obstacle and the <i>dent</i> in the shoreline. In both cases, the obstacle is correctly segmented as non-water region and it can be successfully avoided. However, in first scenario the obstacle is explicitly detected, while second scenario provides us with only indirect detection. To address possible inaccuracies causing dents in the water-edge, the overlap between the dented region and obstacle is defined more strictly as that of water-enclosed obstacles. Note that the proposed treatment of detections is consistent with the problem of obstacle avoidance.

<b>References:</b><br>
[1] <a href="https://ieeexplore.ieee.org/abstract/document/7073635">Kristan, Matej, et al. "Fast Image-Based Obstacle Detection from Unmanned Surface Vehicles."<br>
    IEEE Transactions on cybernetics 46.3 (2015): 641-654.</a><br>
[2] <a href="https://link.springer.com/article/10.1007/s11263-009-0275-4">Everingham, Mark, et al. "The Pascal Visual Object Classes (VOC) Challenge."<br>
		International Journal of Computer Vision 88.2 (2010): 303-338.</a>
