#lang dssl2

let eight_principles = ["Know your rights.",
    "Acknowledge your sources.",
    "Protect your work.",
    "Avoid suspicion.",
    "Do your own work.",
    "Never falsify a record or permit another person to do so.",
    "Never fabricate data, citations, or experimental results.",
    "Always tell the truth when discussing your work with your instructor."]

# Final project: Trip Planner

import cons
import sbox_hash
import 'project-lib/dictionaries.rkt'
import 'project-lib/graph.rkt'
import 'project-lib/binheap.rkt'

### Basic Types ###

#  - Latitudes and longitudes are numbers:
let Lat?  = num?
let Lon?  = num?

#  - Point-of-interest categories and names are strings:
let Cat?  = str?
let Name? = str?

### Raw Item Types ###

#  - Raw positions are 2-element vectors with a latitude and a longitude
let RawPos? = TupC[Lat?, Lon?]

#  - Raw road segments are 4-element vectors with the latitude and
#    longitude of their first endpoint, then the latitude and longitude
#    of their second endpoint
let RawSeg? = TupC[Lat?, Lon?, Lat?, Lon?]

#  - Raw points-of-interest are 4-element vectors with a latitude, a
#    longitude, a point-of-interest category, and a name
let RawPOI? = TupC[Lat?, Lon?, Cat?, Name?]

### Contract Helpers ###

# ListC[T] is a list of `T`s (linear time):
let ListC = Cons.ListC
# List of unspecified element type (constant time):
let List? = Cons.list?


interface TRIP_PLANNER:

    # Returns the positions of all the points-of-interest that belong to
    # the given category.
    def locate_all(
            self,
            dst_cat:  Cat?           # point-of-interest category
        )   ->        ListC[RawPos?] # positions of the POIs

    # Returns the shortest route, if any, from the given source position
    # to the point-of-interest with the given name.
    def plan_route(
            self,
            src_lat:  Lat?,          # starting latitude
            src_lon:  Lon?,          # starting longitude
            dst_name: Name?          # name of goal
        )   ->        ListC[RawPos?] # path to goal

    # Finds no more than `n` points-of-interest of the given category
    # nearest to the source position.
    def find_nearby(
            self,
            src_lat:  Lat?,          # starting latitude
            src_lon:  Lon?,          # starting longitude
            dst_cat:  Cat?,          # point-of-interest category
            n:        nat?           # maximum number of results
        )   ->        ListC[RawPOI?] # list of nearby POIs


struct posn: 
 let lat: Lat?
 let lon: Lon? 
 
struct poi: 
 let posn
 let category: Cat?
 let name: Name?
 
struct priority: #create struct where you can store both index and the distance
 let node_id
 let distance
  
        
class TripPlanner (TRIP_PLANNER):
    let graph #graph of segments
    let posn_id_to_posn #direct addressing for posn to graph
    let posn_to_posn_id # used for keeping track of which posn's we've added
    let i #counts num posns / endpoints on graph
    let posn_id_to_poi #vector of LL of POIs; if no POI, element is None
    let cat_to_posn #hash table for locate_all
    let name_to_posn #hash table for plan_route
#   ^ YOUR CODE GOES HERE
    
    #constructor must take 2 arguments: vec of raw road segments and vec of raw POIs
    def __init__(self, segments, poi_vec):
        self.posn_id_to_posn = [None; 2*segments.len()] #OK to make array longer than needed
        self.posn_to_posn_id = HashTable(2*segments.len(), make_sbox_hash()) #OK to make array longer than needed
        self.i = 0 
        #setting up bidirectional mapping for posns
        for segment in segments: #i's are maintained
            if self.posn_to_posn_id.mem?(posn(segment[0],segment[1])) == False:  #if posn not in hash table:
                #add posn to vector and to hashtable
                self.posn_to_posn_id.put((posn(segment[0],segment[1])), self.i) #key: posn, value: index
                self.posn_id_to_posn[self.i] = posn(segment[0],segment[1])
                #check if other posn is ALSO in hash table               
                if self.posn_to_posn_id.mem?(posn(segment[2],segment[3])) == False:
                    self.posn_to_posn_id.put((posn(segment[2],segment[3])), self.i+1) 
                    self.posn_id_to_posn[self.i+1] = posn(segment[2],segment[3])
                    self.i = self.i+2                        
                else:
                    self.i = self.i+1
            #if first posn is in hash, still need to check if second is
            elif self.posn_to_posn_id.mem?(posn(segment[2],segment[3])) == False:
                self.posn_to_posn_id.put((posn(segment[2],segment[3])), self.i) #indexing this to i instead of i+1
                self.posn_id_to_posn[self.i] = posn(segment[2],segment[3]) #indexing this to i instead of i+1
                self.i = self.i+1  
        #adding posns to graph
        self.graph = WuGraph(self.i) 
        for segment in segments:
            #calculate dist b/w posns
            let lat_dist = segment[0] - segment[2] #distance between lats
            let lon_dist = segment[1] - segment[3] #distance between lons
            let segment_dist = ((lat_dist)**2 + (lon_dist)**2).sqrt()
            #get index of posns
            let posn1_i = self.posn_to_posn_id.get(posn(segment[0],segment[1]))
            let posn2_i = self.posn_to_posn_id.get(posn(segment[2],segment[3]))
            #set edge in weighted undirected graph
            self.graph.set_edge(posn1_i,posn2_i,segment_dist)
            #graph.set_edge(posn2_i,posn1_i, segment_dist) #don't need this because set_edge from WuGraph already maintains symmetry
        #processing POIs: create a vector of structs
        self.posn_id_to_poi = [None; self.posn_id_to_posn.len()] #CHANGE: LENGTH OF POI ID VEC BECAUSE COULD HAVE ONLY 1 POI BUT LOCATION IS AT A LATER POSN
        #category hash table for locate_all
        self.cat_to_posn = HashTable(poi_vec.len(), make_sbox_hash()) #there might be some duplicate categories but OK if hash is a little bigger        
                                                                      #otherwise, need to keep track of number of categories, without making duplicates - adds time complexity
        self.name_to_posn = HashTable(poi_vec.len(), make_sbox_hash()) #confirm this is also good size
        for point in poi_vec:
            let poi_posn = posn(point[0], point[1]) # convert into posn struct #poi_posn = posn(0,0) -> mem?(posn(0,0))
            let cat = point[2]
            let name = point[3]
            #CHANGE: posn_id_to_poi MUST STORE A LL OF POIS BECAUSE THERE CAN BE MULTIPLE POIS AT A GIVE POSN
            if self.posn_to_posn_id.mem?(poi_posn) == True: #if posn is in our dictionary / if it exists at segment endpoint 
                let poi_i = self.posn_to_posn_id.get(poi_posn) #set to same index as dictionary
                #CHANGE: ADDED CHECK TO SEE IF THERE IS ALREADY A POI AT THAT NODE
                if self.posn_id_to_poi[poi_i] is None: #index is empty
                    #CHANGE: AUTOMATICALLY CREATE A LL IN THE VECTOR
                    self.posn_id_to_poi[poi_i] = cons(poi(posn(point[0], point[1]),point[2], point[3]), None)
                else: #CHANGE: APPEND NEW POI TO EXISTING LL
                    self.posn_id_to_poi[poi_i] = cons(poi(posn(point[0], point[1]),point[2], point[3]), self.posn_id_to_poi[poi_i])
            else: error("not in segments list")
            if self.cat_to_posn.mem?(cat)==True: #if the key already exists
                let cat_value = self.cat_to_posn.get(cat) #should be a linked list
                self.cat_to_posn.put(cat, cons(poi_posn, cat_value)) #update value if key exists
            else:
                self.cat_to_posn.put(cat, cons(poi_posn,None))
            if self.name_to_posn.mem?(name)==True: #if the key already exists
                let name_value = self.name_to_posn.get(name) #should be a linked list
                self.name_to_posn.put(name, cons(poi_posn, name_value)) #update value if key exists
            else:
                self.name_to_posn.put(name, poi_posn) #None is an empty LL

                   
    def dijkstra(self, graph, start: nat?):
        #pq keeps track of what you need to check next #initialize priority queue to hold distances
        let pq = BinHeap(graph.len()**2, λ x, y: x.distance < y.distance)  #CHANGE: size of bin heap = max # of edges (V^2) ASK PIAZZA why
        #dist is a vector that keeps track of the distance
        let dist = [inf; graph.len()] #vector size of number of vertices in graph
        #preds is a vector that keeps track of the preceding node
        let preds = [None; graph.len()] #vector size of number of vertices in graph
        #visited keeps track if you've seen it already #initialized full of False (not visited). 
        let visited = [False; graph.len()]
        #adding starting vertex to everyhing
        pq.insert(priority(start,0)) # add start to the pq
        dist[start] = 0
        preds[start] = start
        #relaxing
        while pq.len() != 0:                     
            let current_node = pq.find_min().node_id #A
            #println(current_node) #checks if priority is working properly TEST THIS
            pq.remove_min() #goes through the whole while loop before breaking        
            if visited[current_node] == False:
                visited[current_node] = True
                let neighbors = Cons.to_vec(graph.get_adjacent(current_node)) #returns vector of adjacent nodes
                #println("current node: %p | neighbors vec: %p", current_node, neighbors)
                for neighbor in neighbors: #E F B
                   let n_dist = graph.get_edge(current_node,neighbor) #distance from current_node to neighbor #w
                   #println("dist from %p: %p | n_dist: %p | dist of %p: %p", start, dist[current_node], n_dist, neighbor, dist[neighbor])
                   if dist[current_node] + n_dist < dist[neighbor]:
                       dist[neighbor] = dist[current_node] + n_dist
                       preds[neighbor] = current_node
                       let pri = priority(neighbor,n_dist)
                       pq.insert(pri) #to move method along, you add something to pq
        return [dist, preds]

          
    def plan_route(self, src_lat:Lat?,src_lon:Lon?,dst_name:Name?): #-> ListC[RawPos?] # path to goal
        let start = self.posn_to_posn_id.get(posn(src_lat, src_lon)) #returns the node_id of the starting point
        let start_posn = [src_lat, src_lon]           
        println("start: %p", start)
        let path_posns = None #empty LL
        if self.name_to_posn.mem?(dst_name) == True: #check if the POI exists first so you don't have to run dij           
            let end_posn = self.name_to_posn.get(dst_name)
            println("end_posn: %p", end_posn)
            let end_id = self.posn_to_posn_id.get(end_posn) #returns index
            println("end_id: %p", end_id)
            #NEW: if start = end, you don't need to go through dij
            if start == end_id: path_posns = cons(start_posn, path_posns)
            else:
                let dij_result = self.dijkstra(self.graph, start)
                let dist = dij_result[0]
                let preds = dij_result[1]
                println("dist: %p", dist)
                println("preds: %p", preds)                       
                if dist[end_id] != inf: # if node IS reachable                
                    end_posn = [end_posn.lat, end_posn.lon] #converting posn to RawPos
                    path_posns = cons(end_posn, path_posns)
                    println("path_posns: %p", path_posns)
                    let pred_id = preds[end_id]
                    #finding the path
                    while pred_id != start: #this while loop is only for preds, still need to add start at end
                        let pred_posn = self.posn_id_to_posn.get(pred_id)
                        println("start pred posn: %p; id: %p", pred_posn, pred_id)
                        pred_posn = [pred_posn.lat, pred_posn.lon] 
                        path_posns = cons(pred_posn, path_posns)
                        pred_id = preds[pred_id] #find the next pred
                        println("path_posns: %p", path_posns)
                        println("pred_id round2: %p", pred_id)                           
                    #this is where we add the start
                    path_posns = cons(start_posn, path_posns)
                    println("path_posns: %p", path_posns)
        return path_posns

        
    def locate_all(self, dst_cat: Cat?):#   ->        ListC[RawPos?]
        let posn_hash = HashTable(self.posn_id_to_posn.len(), make_sbox_hash()) #is this the right length?       
        let result_posns = None
        if self.cat_to_posn.mem?(dst_cat) == True:#if the cat exists
            println("cat posn: %p", self.cat_to_posn.get(dst_cat))
            let posn_vec = Cons.to_vec(self.cat_to_posn.get(dst_cat)) #vec of posns for that category
            println("posn_vec: %p", posn_vec) #should be 0,1 
            for element in posn_vec: #hash each posn
                #check if element in posn hash and cons if don't / only put if don't have #before you add, check if added 
                if posn_hash.mem?(element) == False:
                    posn_hash.put(element, element) #random value
                    result_posns = cons([posn_hash.get(element).lat,posn_hash.get(element).lon], result_posns)
            #println("posn_hash: %p", posn_hash)
            println("result_posns: %p", result_posns)           
        return result_posns
         
         
    def find_nearby(self, src_lat:  Lat?, src_lon:  Lon?, dst_cat:  Cat?,n:nat?):#   ->        ListC[RawPOI?] # list of nearby POIs
        let start = self.posn_to_posn_id.get(posn(src_lat, src_lon)) #returns the node_id of the starting point        
        #check if the cat exists before running everything
        let results = None #LL of POIs
        if self.cat_to_posn.mem?(dst_cat) == True:
        #find all the posns for the given cat
            let cat_posns_vec = Cons.to_vec(self.locate_all(dst_cat))  #decision: ok to ignore duplicates for now
            let num_pois_at_cat = Cons.to_vec(self.cat_to_posn.get(dst_cat)).len() #NEW: counting # POIs per category
            let dij_result = self.dijkstra(self.graph, start) 
            let dist = dij_result[0]
            let preds = dij_result[1]
            #find the indicies of all the POIs in the vector
            for i in range(cat_posns_vec.len()):
                #update cat_posns to include struct of index and distance             
                let cat_posn_id = self.posn_to_posn_id.get(posn(cat_posns_vec[i][0],cat_posns_vec[i][1])) #convert back to posn and then to ID
                cat_posns_vec[i] = priority(cat_posn_id, dist[cat_posn_id]) #id, dist
                #    TO DO: WHEN TESTING, TEST THAT DIST IS INDEXING ON THE CORRECT NODE
            println(cat_posns_vec)
            #sorts by distance smallest to greatest
            heap_sort(cat_posns_vec, λ x, y: x.distance < y.distance) #returns dist vec in order
            #println("cat_posns_sorted: %p", cat_posns_sorted)
            let current_n = 0
            #println("current_n at start of while loop: %p", current_n)
            println("cat_posns_vec: %p",cat_posns_vec)
            for element in cat_posns_vec:          
                println("current element: %p", element)                    
                let posn_id = element.node_id #returns id of first element
                if element.distance != inf: # if node IS reachable     #indent everything after
                    #first, check if there are multiple POIs at one node
                    let LL_pois = Cons.to_vec(self.posn_id_to_poi.get(posn_id)) #LL of POIs at ID  
                    println("LL pois at element %p: %p", element, LL_pois)
                    if LL_pois.len()>1:                       
                        for linked_poi in LL_pois:
                            println("linked_poi: %p", linked_poi)
                            #first, make sure cat of poi matches given cat
                            if linked_poi.category == dst_cat:
                                #add each poi to results
                                results = cons([linked_poi.posn.lat,linked_poi.posn.lon,linked_poi.category,linked_poi.name], results)
                                #increment n
                                current_n = current_n + 1
                                if current_n >= n or current_n >= num_pois_at_cat: break #NEW: CHECK
                            println("current_n if multiple: %p", current_n)
                            println("results if multiple: %p", results) 
                        if current_n >= n or current_n >= num_pois_at_cat: break #OH: idk what this is breaking out of but it currently works?   
                    #TEST THIS: because you're iterating a bunch of times, you may increment n without breaking the while loop                   
                    else:                     
                        println("current element in else: %p", element)
                        println("lenth of LL pois: %p", LL_pois.len()) 
                        results = cons([LL_pois[0].posn.lat,
                                        LL_pois[0].posn.lon,
                                        LL_pois[0].category,
                                        LL_pois[0].name],
                                        results)
                        current_n = current_n + 1
                        println("current_n else: %p", current_n)
                        println("results else: %p", results)
                        if current_n >= n or current_n >= num_pois_at_cat: break 
        return results
                
        

def nyc_trip():
    return TripPlanner([[0,0, 5,0],
                        [0,0, 0,20],
                        [0,0, 0,20],
                        [0,20, 5,20],
                        [5,20, 4,6],
                        [4,6, 5,0],
                        [5,0, 3,-2],
                        [0,0, -5,-3],
                        [6,22, 9,22]], #isolated segment
                        [[0,0, "food", "Chelsea Market"],
                        [0,0, "attraction", "High Line"],
                        [0,0, "attraction", "Washington Sq. Park"],
                        [0,0, "attraction", "Hudson Yards"],
                        [-5,-3, "attraction", "World Trade Center"],
                        [3,-2, "bar", "Hair of the Dog"],
                        [3,-2, "bar", "Sweet & Vicious"],
                        [5,0, "attraction", "Empire State Building"],
                        [4,6, "bar", "Clinton Hall"],
                        [4,6, "attraction", "30 Rock"],
                        [4,6, "attraction", "D&P Bench"],
                        [0,20, "bar", "UWS pub"],
                        [5,20, "food", "Ravagh"],
                        [9,22, "attraction", "Brooklyn Bridge"]])
                        

                 

def my_first_example():
    return TripPlanner([[0,0, 0,1], [0,0, 1,0]],
                       [[0,0, "bar", "The Empty Bottle"],
                        [0,1, "food", "Pierogi"]])

test 'My first locate_all test':
    assert my_first_example().locate_all("food") == \
        cons([0,1], None)

test 'My first plan_route test':
   assert my_first_example().plan_route(0, 0, "Pierogi") == \
       cons([0,0], cons([0,1], None))

test 'My first find_nearby test':
    assert my_first_example().find_nearby(0, 0, "food", 1) == \
        cons([0,1, "food", "Pierogi"], None)

test 'find_nearby advanced tests':
    #multiple POIs of the same cat, don't return other pois for same cat that are farther away
    assert nyc_trip().find_nearby(5,0,"bar",3) == \
        cons([4,6, "bar", "Clinton Hall"],cons([3,-2, "bar", "Hair of the Dog"], cons([3,-2, "bar", "Sweet & Vicious"],None)))
    assert Cons.to_vec(nyc_trip().find_nearby(5,0,"bar",3)).len() == 3 #testing results matches given n
    #multiple POIs of diff cat inside same node; for loop should break when you hit n
    assert nyc_trip().find_nearby(5,0,"attraction",3) == \ 
        cons([0,0, "attraction", "Washington Sq. Park"], cons([0,0, "attraction", "Hudson Yards"],cons([5,0, "attraction", "Empire State Building"],None)))
    assert Cons.to_vec(nyc_trip().find_nearby(5,0,"attraction",3)).len() == 3 #testing results matches given n
    assert nyc_trip().find_nearby(5,0,"attraction",9) == \ #when given n is greater than # of attractions 
        cons([-5,-3, "attraction", "World Trade Center"],
        cons([4,6, "attraction", "30 Rock"],
        cons([4,6, "attraction", "D&P Bench"],
        cons([0,0, "attraction", "High Line"],
        cons([0,0, "attraction", "Washington Sq. Park"],
        cons([0,0, "attraction", "Hudson Yards"],
        cons([5,0, "attraction", "Empire State Building"],    
        None)))))))
    assert Cons.to_vec(nyc_trip().find_nearby(5,0,"attraction",9)).len() == 7 #returns only as many attractions as there are (7<9)
    println("~~~~~~~~~~BREAK IN FIND NEARBY TESTS~~~~~~~~~~")
    
test 'plan_route advanced tests':
    #when start = destination
    assert nyc_trip().plan_route(4,6,"30 Rock") == cons([4,6],None)
    #when pred of destination = start
    assert nyc_trip().plan_route(5,0,"D&P Bench") == cons([5,0], cons([4,6],None))
    #traversing a path / when there are multiple ways to get to a dest
    assert nyc_trip().plan_route(3,-2,"UWS pub") == cons([3,-2],cons([5,0],cons([0,0], cons([0,20],None))))
        #not this cons([3,-2],cons([5,0],cons([4,6], cons([5,20], cons([0,20],None)))))
    #return empty list when destination doesn't exist
    assert nyc_trip().plan_route(5,20,"La Caverna") == None
    #return empty list when node is unreachable
    assert nyc_trip().plan_route(5,20,"Brooklyn Bridge") == None
    println("~~~~~~~~~~BREAK IN PLAN ROUTE TESTS~~~~~~~~~~")

   
test 'locate_all advanced tests':
    #despite multiple POIs at one node, does not return duplicate
    assert Cons.to_vec(nyc_trip().locate_all("attraction")).len() == 5
    #returns correct set of RawPos (attraction)
    assert nyc_trip().locate_all("attraction") == \
        cons([0,0], cons([-5,-3], cons([5,0], cons([4,6], cons([9,22], None)))))
    #returns correct set of RawPos (bar)
    assert nyc_trip().locate_all("bar") == \
        cons([3,-2], cons([4,6], cons([0,20], None)))
    #returns correct set of RawPos (food)
    assert nyc_trip().locate_all("food") == \
        cons([0,0], cons([5,20], None))
    #returns nothing if category doesn't exist
    assert nyc_trip().locate_all("museum") == None
    println("~~~~~~~~~~BREAK IN LOCATE ALL TESTS~~~~~~~~~~")


test 'grading report: single POI':
    let tp = TripPlanner([[0, 0, 1, 0]],
                        [[1, 0, 'bank', 'Union']])
    let result = tp.locate_all('bank')
    assert Cons.to_vec(result) == [[1, 0]]
    
test 'grading report: 2 POIs, 1 in relevant category':
    let tp = TripPlanner([[0, 0, 1.5, 0],
                           [1.5, 0, 2.5, 0],
                            [2.5, 0, 3, 0]],
                          [[1.5, 0, 'bank', 'Union'],
                           [2.5, 0, 'barber', 'Tony']])
    let result = tp.locate_all('barber')
    assert Cons.to_vec(result) == [[2.5, 0]]
    
test 'grading report: 4 POIs, 2 in relevant category':    
    let tp = TripPlanner([[0, 0, 1.5, 0],
                           [1.5, 0, 2.5, 0],
                           [2.5, 0, 3, 0],
                           [4, 0, 5, 0]],
                          [[1.5, 0, 'bank', 'Union'],
                           [3, 0, 'barber', 'Tony'],
                           [4, 0, 'food', 'Jollibee'],
                           [5, 0, 'barber', 'Judy']])
    let result = tp.locate_all('barber')
    assert Cons.to_vec(result) == [[3, 0], [5, 0]]

    
test 'grading report: multiple POIs in the same location, relevant one is first':
    let tp = TripPlanner(
      [[0, 0, 1.5, 0],
       [1.5, 0, 2.5, 0],
       [2.5, 0, 3, 0],
       [4, 0, 5, 0],
       [3, 0, 4, 0]],
      [[1.5, 0, 'bank', 'Union'],
       [3, 0, 'barber', 'Tony'],
       [5, 0, 'bar', 'Pasta'],
       [5, 0, 'barber', 'Judy'],
       [5, 0, 'food', 'Jollibee']])
    let result = tp.locate_all('bar')
    assert Cons.to_vec(result) == [[5, 0]]

test 'grading report: multiple POIs in the same location, relevant one is last':
    let tp = TripPlanner(
    [[0, 0, 1.5, 0],
    [1.5, 0, 2.5, 0],
    [2.5, 0, 3, 0],
    [4, 0, 5, 0],
    [3, 0, 4, 0]],
    [[1.5, 0, 'bank', 'Union'],
    [3, 0, 'barber', 'Tony'],
    [5, 0, 'barber', 'Judy'],
    [5, 0, 'bar', 'Pasta'],
    [5, 0, 'food', 'Jollibee']])
    let result = tp.locate_all('bar')
    assert Cons.to_vec(result) == [[5, 0]]

test 'grading report: multiple POIs in the same location, two relevant ones':
    let tp = TripPlanner(
      [[0, 0, 1.5, 0],
       [1.5, 0, 2.5, 0],
       [2.5, 0, 3, 0],
       [4, 0, 5, 0],
       [3, 0, 4, 0]],
      [[1.5, 0, 'bank', 'Union'],
       [3, 0, 'barber', 'Tony'],
       [5, 0, 'bar', 'Pasta'],
       [5, 0, 'barber', 'Judy'],
       [5, 0, 'food', 'Jollibee']])
    let result = tp.locate_all('barber')
    assert Cons.to_vec(result) == [[3, 0], [5, 0]]

test 'grading report: 3 relevant POIs, 2 at same location':
    let tp = TripPlanner(
      [[0, 0, 1.5, 0],
       [1.5, 0, 2.5, 0],
       [2.5, 0, 3, 0],
       [4, 0, 5, 0],
       [3, 0, 4, 0]],
      [[1.5, 0, 'bank', 'Union'],
       [3, 0, 'barber', 'Tony'],
       [5, 0, 'barber', 'Judy'],
       [5, 0, 'barber', 'Lily']])
    let result = tp.locate_all('barber')
    assert Cons.to_vec(result) == [[3, 0], [5, 0]]

test 'grading report: 2-step route':
    let tp = TripPlanner(
      [[0, 0, 1.5, 0],
       [1.5, 0, 2.5, 0],
       [2.5, 0, 3, 0]],
      [[1.5, 0, 'bank', 'Union'],
       [2.5, 0, 'barber', 'Tony']])
    let result = tp.plan_route(0, 0, 'Tony')
    assert Cons.to_vec(result) == [[0, 0], [1.5, 0], [2.5, 0]]
    
test 'grading report: 3-step route':
    let tp = TripPlanner(
      [[0, 0, 1.5, 0],
       [1.5, 0, 2.5, 0],
       [2.5, 0, 3, 0]],
      [[1.5, 0, 'bank', 'Union'],
       [3, 0, 'barber', 'Tony']])
    let result = tp.plan_route(0, 0, 'Tony')
    assert Cons.to_vec(result) == [[0, 0], [1.5, 0], [2.5, 0], [3, 0]]

test 'grading report: from barber to bank':
    let tp = TripPlanner(
      [[0, 0, 1.5, 0],
       [1.5, 0, 2.5, 0],
       [2.5, 0, 3, 0]],
      [[1.5, 0, 'bank', 'Union'],
       [3, 0, 'barber', 'Tony']])
    let result = tp.plan_route(3, 0, 'Union')
    assert Cons.to_vec(result) == [[3, 0], [2.5, 0], [1.5, 0]]

test 'grading report: 0-step route':
    let tp = TripPlanner(
      [[0, 0, 1, 0]],
      [[0, 0, 'bank', 'Union']])
    let result = tp.plan_route(0, 0, 'Union')
    assert Cons.to_vec(result)  == [[0, 0]]
    
test 'grading report: Destination isnt reachable':
    let tp = TripPlanner(
      [[0, 0, 1.5, 0],
       [1.5, 0, 2.5, 0],
       [2.5, 0, 3, 0],
       [4, 0, 5, 0]],
      [[1.5, 0, 'bank', 'Union'],
       [3, 0, 'barber', 'Tony'],
       [5, 0, 'barber', 'Judy']])
    let result = tp.plan_route(0, 0, 'Judy')
    assert Cons.to_vec(result)  == []

test 'grading report: BFS is not SSSP (route)':
    let tp = TripPlanner(
      [[0, 0, 0, 9],
       [0, 9, 9, 9],
       [0, 0, 1, 1],
       [1, 1, 2, 2],
       [2, 2, 3, 3],
       [3, 3, 4, 4],
       [4, 4, 5, 5],
       [5, 5, 6, 6],
       [6, 6, 7, 7],
       [7, 7, 8, 8],
       [8, 8, 9, 9]],
      [[7, 7, 'haberdasher', 'Archit'],
       [8, 8, 'haberdasher', 'Braden'],
       [9, 9, 'haberdasher', 'Cem']])
    let result = tp.plan_route(0, 0, 'Cem')
    assert Cons.to_vec(result) == [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6], [7, 7], [8, 8], [9, 9]]
    
test 'grading report: MST is not SSSP (route)':
    let tp = TripPlanner(
      [[-1.1, -1.1, 0, 0],
       [0, 0, 3, 0],
       [3, 0, 3, 3],
       [3, 3, 3, 4],
       [0, 0, 3, 4]],
      [[0, 0, 'food', 'Sandwiches'],
       [3, 0, 'bank', 'Union'],
       [3, 3, 'barber', 'Judy'],
       [3, 4, 'barber', 'Tony']])
    let result = tp.plan_route(-1.1, -1.1, 'Tony')
    assert Cons.to_vec(result) == [[-1.1, -1.1], [0, 0], [3, 4]]
    
test 'grading report: Destination is the 2nd of 3 POIs at that location':
    let tp = TripPlanner(
      [[0, 0, 1.5, 0],
       [1.5, 0, 2.5, 0],
       [2.5, 0, 3, 0],
       [4, 0, 5, 0],
       [3, 0, 4, 0]],
      [[1.5, 0, 'bank', 'Union'],
       [3, 0, 'barber', 'Tony'],
       [5, 0, 'bar', 'Pasta'],
       [5, 0, 'barber', 'Judy'],
       [5, 0, 'food', 'Jollibee']])
    let result = tp.plan_route(0, 0, 'Judy')
    assert Cons.to_vec(result) == [[0, 0], [1.5, 0], [2.5, 0], [3, 0], [4, 0], [5, 0]]

test 'grading report: Two equivalent routes':
    let tp = TripPlanner(
      [[-2, 0, 0, 2],
       [0, 2, 2, 0],
       [2, 0, 0, -2],
       [0, -2, -2, 0]],
      [[2, 0, 'cooper', 'Dennis']])
    let result = tp.plan_route(-2, 0, 'Dennis')
    #reproducing "is one of"
    #assert Cons.to_vec(result) == [[-2, 0], [0, 2], [2, 0]] - FALSE
    assert Cons.to_vec(result) == [[-2, 0], [0, -2], [2, 0]]


test 'grading report: BinHeap needs capacity > |V|':
    let tp = TripPlanner(
      [[0, 0, 0, 1],
       [0, 1, 3, 0],
       [0, 1, 4, 0],
       [0, 1, 5, 0],
       [0, 1, 6, 0],
       [0, 0, 1, 1],
       [1, 1, 3, 0],
       [1, 1, 4, 0],
       [1, 1, 5, 0],
       [1, 1, 6, 0],
       [0, 0, 2, 1],
       [2, 1, 3, 0],
       [2, 1, 4, 0],
       [2, 1, 5, 0],
       [2, 1, 6, 0]],
      [[0, 0, 'blacksmith', "Revere's Silver Shop"],
       [6, 0, 'church', 'Old North Church']])
    let result = tp.plan_route(0, 0, 'Old North Church')
    assert Cons.to_vec(result) \
      == [[0, 0], [2, 1], [6, 0]]
      
  
'''test 'grading report: Construct PDF example map':
    
#to do after resolving contract issue from grading report: 
 #Failed test: Construct PDF example map (tests/tests7-basic-locate.rkt:13:4)
    #Failed test: Construct map with negative lat/lon (tests/tests7-advanced-locate.rkt:13:4)
    #Failed test: Construct map with large lat/lon (tests/tests7-advanced-locate.rkt:13:4)
#TO DO: Add a highly dense map for binheap stress test
#TO DO: 
#test 'dijkstra advanced tests':
   # assert nyc_trip().
#To DO: find nearby: try again where there are multiple possible paths
      #cons([3,-2],cons([5,0],cons([4,6], cons([5,20], cons([0,20],None)))))
    #Piazza : is there a way to replicate "either or'''