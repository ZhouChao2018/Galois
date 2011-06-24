/*
 * GrowBisection.cpp
 *
 *  Created on: Jun 16, 2011
 *      Author: xinsui
 */
#include "GMetisConfig.h"
#include "MetisGraph.h"
#include "PMetis.h"
#include "defs.h"
#include <climits>
static const int SMALL_NUM_ITER_PARTITION = 3;
static const int LARGE_NUM_ITER_PARTITION = 8;
//private static Random random = Launcher.getLauncher().getRandom(0);

void bisection(GGraph* graph, GNode* nodes, int numNodes, int minWgtPart1, int maxWgtPart1, int* pwgts) {
	int* visited = new int[numNodes];
	int* queue = new int[numNodes];
	arrayFill(visited, numNodes, 0);
	queue[0] = getRandom(numNodes);
	visited[queue[0]] = 1;
	int first = 0;
	int last = 1;
	int nleft = numNodes - 1;
	bool drain = false;
	for (;;) {
		if (first == last) {
			if (nleft == 0 || drain) {
				break;
			}

			int k = getRandom(nleft);
			int i = 0;
			for (; i < numNodes; i++) {
				if (visited[i] == 0) {
					if (k == 0) {
						break;
					} else {
						k--;
					}
				}
			}
			queue[0] = i;
			visited[i] = 1;
			first = 0;
			last = 1;
			nleft--;
		}

		int i = queue[first++];
		int nodeWeight = nodes[i].getData().getWeight();

		if (pwgts[0] > 0 && (pwgts[1] - nodeWeight) < minWgtPart1) {
			drain = true;
			continue;
		}

		nodes[i].getData().setPartition(0);
		pwgts[0] += nodeWeight;
		pwgts[1] -= nodeWeight;
		if (pwgts[1] <= maxWgtPart1) {
			break;
		}

		drain = false;

		for (GGraph::neighbor_iterator jj = graph->neighbor_begin(nodes[i], Galois::Graph::NONE, 0), eejj = graph->neighbor_end(nodes[i], Galois::Graph::NONE, 0); jj != eejj; ++jj) {
			GNode neighbor = *jj;
			int k = neighbor.getData().getNodeId();//id is same as the position in nodes array
			if (visited[k] == 0) {
				queue[last++] = k;
				visited[k] = 1;
				nleft--;
			}
		}
	}
}

void bisection(MetisGraph* metisGraph, int* tpwgts, int coarsenTo) {

	GGraph* graph = metisGraph->getGraph();
	int numNodes = graph->size();
	GNode* nodes = new GNode[numNodes];

	for (GGraph::active_iterator ii = graph->active_begin(), ee = graph->active_end(); ii != ee; ++ii) {
		GNode node = *ii;
		nodes[node.getData().getNodeId()] = node;
	}

	int nbfs = (numNodes <= coarsenTo ? SMALL_NUM_ITER_PARTITION : LARGE_NUM_ITER_PARTITION);

	int maxWgtPart1 = (int) PMetis::UB_FACTOR * tpwgts[1];
	int minWgtPart1 = (int) (1.0 / PMetis::UB_FACTOR) * tpwgts[1];

	int bestMinCut = INT_MAX;
	int* bestWhere = new int[numNodes];

	for (; nbfs > 0; nbfs--) {

		int pwgts[2];
		pwgts[1] = tpwgts[0] + tpwgts[1];
		pwgts[0] = 0;

		for (int i = 0; i < numNodes; i++) {
			nodes[i].getData().setPartition(1);
		}

		bisection(graph, nodes, numNodes, minWgtPart1, maxWgtPart1, pwgts);
		/* Check to see if we hit any bad limiting cases */
		if (pwgts[1] == 0) {
			int i = getRandom(numNodes);
			MetisNode nodeData = nodes[i].getData();
			nodeData.setPartition(1);
			pwgts[0] += nodeData.getWeight();
			pwgts[1] -= nodeData.getWeight();
		}

		metisGraph->computeTwoWayPartitionParams();
//		balanceTwoWay(metisGraph, tpwgts);
		fmTwoWayEdgeRefine(metisGraph, tpwgts, 4);

		if (bestMinCut > metisGraph->getMinCut()) {
			bestMinCut = metisGraph->getMinCut();
			for (int i = 0; i < numNodes; i++) {
				bestWhere[i] = nodes[i].getData().getPartition();
			}
		}
	}
	for (int i = 0; i < numNodes; i++) {
		nodes[i].getData().setPartition(bestWhere[i]);
		assert(nodes[i].getData().getPartition()>=0);
	}
	delete[] bestWhere;
	metisGraph->setMinCut(bestMinCut);
//	metisGraph->verify();
}


