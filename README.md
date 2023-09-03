# Trip-Planner
Trip-planning API that provides routing and searching services

## Project Details
- Context: Final project for CS-214: Data Structures & Algorithms [(syllabus)](https://drive.google.com/file/d/1riDzUiFLU5B3p4NK5gMSQ7cvKDDtP_cX/view?usp=sharing) with Prof. Vincent St.-Amour at Northwestern University's McCormick School of Engineering.
Learning Goal: Choose and implement appropriate data structures and algorithms to achieve requirements while maintaining efficient space and time complexity.

## Requirements
- Locate-all: Takes a point-of-interest category (i.e., bar, park) as input and returns all of the points-of-interest in that category
- Plan-route: Takes a starting position (lat, lon) and a destination (lat,lon) as input and returns the shortest path from start to finish
- Find-nearby: Takes a starting position (lat, lon), a point-of-interest category, and limit n, and returns up to n points-of-interest with the given category nearby, in order from closest to farthest


## Select Abstract Data Types (ADTs), Purpose + Rationale
| ADT | Purpose | Data Structure | Rationale |
| -------- | -------------------- | ----------- | -------------------------- |
| Weighted, Undirected Graph | Represents all the two-way (i.e., undirected) connections between different positions in a TripPlanner. Each vertex of the graph translates to the index of a position, each edge represents the road segment connecting the positions, and each edge’s weight represents the Euclidean distance between two road segment endpoints | Adjacency Matrix | The adjacency matrix has a time complexity advantage over the adjacency list (constant time O(1) vs. linear O(d)) for various TripPlanner queries |

