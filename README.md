# Trip-Planner
Trip-planning API that provides routing and searching services

## Project Details
- Context: Final project for CS-214: Data Structures & Algorithms [(syllabus)](https://drive.google.com/file/d/1riDzUiFLU5B3p4NK5gMSQ7cvKDDtP_cX/view?usp=sharing) with Prof. Vincent St.-Amour at Northwestern University's McCormick School of Engineering.
Learning Goal: Choose and implement appropriate data structures and algorithms to achieve requirements while maintaining efficient space and time complexity.

## Requirements
- Locate-all: Takes a point-of-interest category (i.e., bar, park) as input and returns all of the points-of-interest in that category
- Plan-route: Takes a starting position (lat, lon) and a destination (lat,lon) as input and returns the shortest path from start to finish
- Find-nearby: Takes a starting position (lat, lon), a point-of-interest category, and limit n, and returns up to n points-of-interest with the given category nearby, in order from closest to farthest


## Select Abstract Data Types (ADTs), Data Structures (DS), Purpose + Rationale
| ADT | Purpose | DS | Rationale |
| -------- | -------------------- | ----------- | -------------------------- |
| Weighted, Undirected Graph | Represents all the two-way (i.e., undirected) connections between different positions in a TripPlanner. Each vertex of the graph translates to the index of a position, each edge represents the road segment connecting the positions, and each edge’s weight represents the Euclidean distance between two road segment endpoints | Adjacency Matrix | The adjacency matrix has a time complexity advantage over the adjacency list (constant time O(1) vs. linear O(d)) for various TripPlanner queries | 
Dictionary | Bi-directional mapping (1/2 DS) | Direct-addressing vector | Whenever keys can be represented as natural numbers, a direct addressing vector is my first choice because: 1/ it’s faster to construct than a hash table and insertion/lookup are both consistently O(1), vs. hash tables which take constant time on average and 2/ it’s overall faster than an association list, which has linear O(n) time complexity for both the aforementioned methods |
Dictionary | Find the position of a POI with a _specific name_, where name is the key and a position struct is the value | Hash table (separate chaining) | Hash tables have constant time O(1) for lookup on average, compared to association lists and sorted arrays, which have O(n) and O(logn) time complexity, respectively |
Priority Queue | Created specifically for _Dijkstra_ and returning the vertex closest to a given starting vertex. Holds priority-value pairs, where the priority is the distance from the starting vertex (v) to another vertex (u) and the value is graph vertex (u) | Binary Heap | The binary heap’s invariant–which is that it must be a complete, heap-ordered binary tree–allows us to both insert and remove elements from the priority queue with O(logn) time complexity. This is faster than sorted or unsorted lists, which take linear O(n) time for insert and remove operations, respectively.|

## Algorithms
1. Dijkstra
- Role: Helper function for plan_route and find_nearby to determine the shortest path from a client-entered starting point to either a specific destination (plan_route) or a POI category (find_nearby). In addition to returning the shortest paths, it returns the predecessors of each vertex, which is used in plan_route to map out each position along the route from a given starting point to a destination. 
- Rationale: The other option was Bellman-Ford, which is a brute-force algorithm that relaxes each edge |V|-1 times in an arbitrary order and takes up to O(|V|^3) time to find the shortest path in the worst case. Dijkstra, however, relaxes the neighboring edges of the closest vertex and repeats this until each edge is relaxed only once. As a result, Dijkstra’s time efficiency is only O(|V|^2log|V|) and therefore a better choice for finding the shortest path. 

2. Heap_sort 
- Role: Used in find_nearby to sort the positions (graph indices) of a provided category in order of increasing distance from the provided starting point. Rather than looping through the unsorted array of positions to find the nearest POIs, heap_sort allows us to loop through the sorted output and only return the first n results.
- Rationale: Since heap_sort relies on a binary heap, which is heap-ordered by priority (in this case shortest distance), its time complexity is O(nlogn), which is the same as merge sort but faster than selection sort, O(n^2).

