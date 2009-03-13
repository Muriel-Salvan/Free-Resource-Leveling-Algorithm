
require 'date'

$Debug = true
if ($Debug)
  require 'pp'
end

# Uncomment to debug within unit tests
#require 'rubygems'
#require 'ruby-debug/debugger'

require 'ProjectLeveling/ProjectLeveling_ImportanceManager'
require 'ProjectLeveling/ProjectLeveling_SolutionManager'
require 'ProjectLeveling/ProjectLeveling_TaskAssignmentManager'
require 'ProjectLeveling/ProjectLeveling_PathsManager'

module ProjectLeveling

  # The following types just mention what will be used by the algorithm only
  
  # Class representing a Project
  class Project
  
    # The start date
    #   Date
    attr_accessor :StartDate

    # The end date
    #   Date
    attr_accessor :EndDate
    
    # Constructor
    #
    # Parameters:
    # * *iStartDate* (_Date_): The start date
    # * *iEndDate* (_Date_): The end date
    def initialize(iStartDate, iEndDate)
      @StartDate = iStartDate
      @EndDate = iEndDate
    end
    
  end

  # Class representing a task
  class Task

    # The priority
    #   Integer
    attr_accessor :Priority
    
    # The sizing, in hours
    #   Integer
    attr_accessor :Sizing
    
    # The list of resources that can be assigned, with their assignment effort in hours
    #   map< Resource, Integer >
    attr_accessor :ResourcesMap
    
    # The list of successors
    #   list< Task >
    attr_accessor :Successors
    
    # The name (used in debug only)
    #   String
    attr_accessor :Name
    
    # Constructor
    #
    # Parameters:
    # * *iName* (_String_): The name of the task (used in debug mode only)
    # * *iPriority* (_Integer_): The priority
    # * *iSizing* (_Integer_): The sizing
    # * *iResourcesMap* (<em>map<Resource,Integer></em>): The resources
    # * *iSuccessorsList* (<em>list<Task></em>): The list of successors
    def initialize(iName, iPriority, iSizing, iResourcesMap, iSuccessorsList)
      @Name = iName
      @Priority = iPriority
      @Sizing = iSizing
      @ResourcesMap = iResourcesMap
      @Successors = iSuccessorsList
      # Also initialize internal attributes
      @Predecessors = []
      @AccessibleTasks = {}
      @SharingResourcesTasksID = nil
    end
    
    # Build predecessors
    #
    # Parameters:
    # * *iTasksList* (<em>list<Task></em>): The list of tasks to consider to populate predecessors
    def self.populatePredecessors(iTasksList)
      iTasksList.each do |iTask|
        iTask.Successors.each do |iChildTask|
          iChildTask.Predecessors << iTask
        end
      end
    end
    
    # Build sharing resources tasks IDs
    #
    # Parameters:
    # * *iTasksList* (<em>list<Task></em>): The list of tasks to consider to populate predecessors
    def self.populateSharingResourcesTasksID(iTasksList)
      # Map storing all partitions: the set of Tasks per set of resources.
      # map< map< Resource, nil >, map< Task, nil > >
      lResourcesPartitionsMap = {}
      iTasksList.each do |iTask|
        # Find out if iTask has some resources in common with already existing partitions.
        # List of partitions sharing resources with iTask.
        # list< map< Resource, nil > >
        lIntersectingPartitionsList = []
        lResourcesPartitionsMap.each do |iResourcesSet, iTasksSet|
          if (!(iResourcesSet.keys & iTask.ResourcesMap.keys).empty?)
            # This map shares resources with iTask. Remember it.
            lIntersectingPartitionsList << iResourcesSet
          end
        end
        if ($Debug)
          lStrResourcesSet = []
          iTask.ResourcesMap.keys.each do |iResource|
            lStrResourcesSet << iResource.Name
          end
          puts "#{iTask.Name} has resources ([#{lStrResourcesSet.join(', ')}]) also part of the following partitions:"
          lIntersectingPartitionsList.each do |iResourcesSet|
            lStrResourcesSet = []
            iResourcesSet.each do |iResource, iNil|
              lStrResourcesSet << iResource.Name
            end
            puts "  - [#{lStrResourcesSet.join(', ')}]"
          end
        end
        # 3 cases:
        # 1. If there is no partition found, create a new one with iTask alone inside.
        # 2. If there is exactly 1 existing partition, just add iTask in the partition.
        # 3. If there are 2 or more partitions, we have to merge all of them and add iTask in the result.
        if (lIntersectingPartitionsList.empty?)
          # Build the new set
          # map< Resource, nil >
          lNewResourceSet = {}
          iTask.ResourcesMap.keys.each do |iResource|
            lNewResourceSet[iResource] = nil
          end
          lResourcesPartitionsMap[lNewResourceSet] = { iTask => nil }
        elsif (lIntersectingPartitionsList.size == 1)
          lResourcesPartitionsMap[lIntersectingPartitionsList[0]][iTask] = nil
          # Add eventually additional resources from iTask
          iTask.ResourcesMap.keys.each do |iResource|
            lIntersectingPartitionsList[0][iResource] = nil
          end
        else
          # The new resources set
          # map< Resource, nil >
          lNewResourcesSet = {}
          # The new tasks set
          # map< Task, nil >
          lNewTasksSet = {}
          lIntersectingPartitionsList.each do |iResourcesSet|
            # Merge the resources set
            lNewResourcesSet.merge!(iResourcesSet)
            # Merge the tasks set
            lNewTasksSet.merge!(lResourcesPartitionsMap[iResourcesSet])
          end
          # Add iTask also
          lNewTasksSet[iTask] = nil
          # Add eventually additional resources from iTask
          iTask.ResourcesMap.keys.each do |iResource|
            lNewResourcesSet[iResource] = nil
          end
          # Delete old partitions
          lResourcesPartitionsMap.delete_if do |iResourcesSet, iTasksSet|
            lIntersectingPartitionsList.include?(iResourcesSet)
          end
          # Add the new one
          lResourcesPartitionsMap[lNewResourcesSet] = lNewTasksSet
        end
      end
      if ($Debug)
        puts "Resulting partitions map after considering all tasks:"
        lResourcesPartitionsMap.each do |iResourcesSet, iTasksSet|
          lStrResourcesSet = []
          iResourcesSet.each do |iResource, iNil|
            lStrResourcesSet << iResource.Name
          end
          lStrTasksSet = []
          iTasksSet.each do |iTask, iNil|
            lStrTasksSet << iTask.Name
          end
          puts "  - [#{lStrResourcesSet.join(', ')}] => [#{lStrTasksSet.join(', ')}]"
        end
      end
      # Now affect unique ID to each partition, and store it in each task
      lIdxID = 0
      lResourcesPartitionsMap.each do |iResourcesSet, iTasksSet|
        iTasksSet.keys.each do |iTask|
          iTask.SharingResourcesTasksID = lIdxID
        end
        lIdxID += 1
      end
    end
    
    # The following attributes are helpers used internally by the algorithm and do not
    # need any initialization from the client.
    
    # The list of predecessors
    #   list< Task >
    attr_accessor :Predecessors
    
    # The sharing resources partition ID
    #   Integer
    attr_accessor :SharingResourcesTasksID
    
  end

  # Class representing a resource
  class Resource

    # The availability, in hours per day
    #   map< Date, Integer >
    attr_accessor :AvailabilityMap
    
    # The name (used in debug only)
    #   String
    attr_accessor :Name
    
    # Constructor
    #
    # Parameters:
    # * *iName* (_String_): The name of the resource (used in debug mode only)
    # * *iAvailabilityMap* (<em>map<Date,Integer></em>): The availability calendar
    def initialize(iName, iAvailabilityMap)
      @Name = iName
      @AvailabilityMap = iAvailabilityMap
    end
    
  end

  # Class representing the output of the algorithm: hours assigned per day, per resource,
  # per task.
  #   Assignment = map< Task, map< Resource, map< Date, Integer > > >
  
  # The following class represents the importance of a task.
  class Importance_Type
    # TODO: Implement it
  end
  
  if ($Debug)

    # Display a tasks' list (debug only)
    #
    # Parameters:
    # * *iTasksList* (<em>list<Task></em>): The tasks list
    # * *iDetailed* (_Boolean_): Detailed display [optiona = false]
    def self.displayTasksList(iTasksList, iDetailed = false)
      iTasksList.each do |iTask|
        if (iDetailed)
          lStrResources = []
          iTask.ResourcesMap.each do |iResource, iHours|
            lStrResources << "#{iResource.Name}(#{iHours})"
          end
          lStrPredecessors = []
          iTask.Predecessors.each do |iPredecessorTask|
            lStrPredecessors << iPredecessorTask.Name
          end
          lStrSuccessors = []
          iTask.Successors.each do |iSuccessorTask|
            lStrSuccessors << iSuccessorTask.Name
          end
          puts "- #{iTask.Name} (#{iTask.Priority}) Sizing=#{iTask.Sizing} Resources=[#{lStrResources.join(', ')}] Predecessors=[#{lStrPredecessors.join(', ')}] Successors=[#{lStrSuccessors.join(', ')}] SharingResourcesTasksID=#{iTask.SharingResourcesTasksID}"
        else
          puts "- #{iTask.Name} (#{iTask.Priority})"
        end
      end
    end
    
  end
  
  # The main algorithm
  #
  # Parameters:
  # * *iTasksList* (<em>list<Task></em>): The list of tasks to level
  # * *iProject* (_Project_): The project
  # Return:
  # * <em>AssignmentInfo_Type</em>: The assignment, or nil if impossible
  # * <em>list<[Task,String]></em>: In case of error, the tasks in error we can't level along with their error message
  def self.levelProject(iTasksList, iProject)
    # 1.
    if ($Debug)
      puts 'Call levelProject with the following tasks list:'
      ProjectLeveling.displayTasksList(iTasksList, true)
    end
    lInitialAssignment = SolutionManager::AssignmentInfo_Type.new
    if (iTasksList.empty?)
      # I know it was not specified, but regression tests empty projects too ;-)
      return lInitialAssignment, nil
    end
    lAlreadyTriedPaths = PathsManager::PathNode_Type.new(nil, Float::MAX, {})
    # TODO: Remove when PathsManager.findPossibleBetterPathForTask does not use it anymore
    $AlreadyTriedPaths = lAlreadyTriedPaths
    lCurrentPathMinimalImportance = nil
    lAssignmentStrategies = [ SolutionManager::AS1ResPerTask.new(10) ]
#    lAssignmentStrategies = [ AS1ResPerTask.new(10),
#                              ASResDontJumpTasks.new(20),
#                              ASResNoSeveralTasksPerDay.new(15),
#                              ASDontSplitTasks.new(5),
#                              ASCompleteEarliestPossible.new(18) ]
    # 2.
    # Sort the tasks before
    lSortedTasksBySuccessors = []
    # List containing a clone of the list to sort: we will delete inserted tasks little
    # by little from it.
    lTasksToBeSorted = iTasksList.clone
    while (!lTasksToBeSorted.empty?)
      # Remember the tasks to delete
      lTasksToDelete = []
      lTasksToBeSorted.each do |iTask|
        lAllPredecessorsProcessed = true
        iTask.Predecessors.each do |iParentTask|
          if (!lSortedTasksBySuccessors.include?(iParentTask))
            # iParentTask has not yet been inserted in lSortedTasksBySuccessors
            lAllPredecessorsProcessed = false
            break
          end
        end
        if (lAllPredecessorsProcessed)
          # All predecessors were inserted: we can insert this one now
          lSortedTasksBySuccessors << iTask
          lTasksToDelete << iTask
        end
      end
      lTasksToBeSorted.delete_if do |iTask|
        lTasksToDelete.include?(iTask)
      end
    end
    if ($Debug)
      puts 'Tasks sorted by successors:'
      self.displayTasksList(lSortedTasksBySuccessors)
    end
    lSortedTasksBySuccessors.each do |iTask|
      # 2.1.
      # Compute the minimal start date, as the latest end date of each predecessor, + 1
      lMinStartDate = nil
      iTask.Predecessors.each do |iParentTask|
        if ((lMinStartDate == nil) or
            (lInitialAssignment[iParentTask].MinEndDate + 1 > lMinStartDate))
          lMinStartDate = lInitialAssignment[iParentTask].MinEndDate + 1
        end
      end
      # Please note that lMinStartDate can be nil if no predecessor was found.
      # 2.2.
      lInitialAssignment[iTask] = SolutionManager::AssignmentInfoPerTask_Type.new
      lNewTaskInfo = lInitialAssignment[iTask]
      # Fill in the calendar of available resources
      # - AvailableResourcesSlot
      # - AvailableHours
      # - MinStartDate
      # - MinEndDate
      # - MinEndDateHours
      # - MaxEndDate
      lStartDay = nil
      lEndDay = nil
      lNewTaskInfo.AvailableHours = 0
      lNewTaskInfo.AvailableResourcesSlots = {}
      lNewTaskInfo.ResourcesBuffers = {}
      iTask.ResourcesMap.each do |iResource, iMaximalSizingHours|
        iResource.AvailabilityMap.each do |iDay, iWorkingHours|
          # Do not consider days before the minimal start date
          if ((lMinStartDate == nil) or
              (iDay >= lMinStartDate))
            if (lNewTaskInfo.AvailableResourcesSlots[iDay] == nil)
              # A brand new day found for this task
              lNewTaskInfo.AvailableResourcesSlots[iDay] = {}
              if ((lStartDay == nil) or
                  (iDay < lStartDay))
                lStartDay = iDay
              end
              if ((lEndDay == nil) or
                  (iDay > lEndDay))
                lEndDay = iDay
              end
            end
            # Add this resource as available for this day and task
            lNewTaskInfo.AvailableResourcesSlots[iDay][iResource] = iWorkingHours
            lNewTaskInfo.AvailableHours += iWorkingHours
            if (!lNewTaskInfo.ResourcesBuffers.has_key?(iResource))
              lNewTaskInfo.ResourcesBuffers[iResource] = SolutionManager::ResourceBuffers_Type.new
            end
          end
        end
      end
      # Now get the minimal end date and end date hours: we start from lStartDay, and
      # count available resources until we reach lEndDay or the task's sizing.
      lNewTaskInfo.MinStartDate = lStartDay
      lNewTaskInfo.MaxEndDate = lEndDay
      # - Other attributes
      lNewTaskInfo.FinalAssignment = nil
      lNewTaskInfo.FinalAssignmentMeasures = nil
      lNewTaskInfo.Importance = nil
      lNewTaskInfo.NonOptimalAccumulatedDelay = 0
      lNewTaskInfo.MinEndDate, lNewTaskInfo.MinEndDateHours = TaskAssignmentManager.computeShiftedDateHours(iTask, lStartDay, 0, iTask.Sizing, lInitialAssignment)
      # 2.3.
      if (lNewTaskInfo.AvailableHours < iTask.Sizing)
        # 2.3.1.
        return nil, [ [ iTask, 'Not enough resources' ] ]
      # 2.4.
      elsif (lNewTaskInfo.AvailableHours == iTask.Sizing)
        # 2.4.1.
        lConsequences = ShiftedTaskConsequences_Type.new
        # 2.4.2.
        SolutionManager.assignCompleteTask(iTask, [], lInitialAssignment, nil, nil, lConsequences, lAssignmentStrategies)
        # 2.4.3.
        if (!lConsequences.PossibleConsequence)
          # TODO: Interpret lConsequences
          return nil, [ [ iTask, lConsequences ] ]
        end
      end
    end
    # 3.
    iTasksList.each do |iTask|
      if (iTask.Predecessors.empty?)
        # 3.1.
        ImportanceManager.populateImportances(iTask, lInitialAssignment)
      end
    end
    if ($Debug)
      puts 'Initial assignment:'
      SolutionManager.displayAssignmentInfo(lInitialAssignment, true)
    end
    # 4.
    iTasksList.each do |iTask|
      # 4.1.
      if (iTask.Predecessors.empty?)
        # 4.1.1.
        lAlreadyTriedPaths.TaskPaths[iTask] = nil
      end
    end
    # 5.
    lSortedTasksList = ImportanceManager.getSortedTasks(iTasksList, lInitialAssignment)
    if ($Debug)
      puts 'First sorted tasks list:'
      SolutionManager.displayAssignedTasksList(lSortedTasksList, lInitialAssignment)
      puts 'First paths tree:'
      PathsManager.displayTree(lAlreadyTriedPaths)
    end
    # 6.
    # Clone the initial assignment before modifying it, as it will be useful to compare solutions afterwards
    lBestImpossibleAssignment = lInitialAssignment.clone
    lPossibleAssignments = SolutionManager.findAssignmentForTaskList(lSortedTasksList, lInitialAssignment, lAlreadyTriedPaths, lAssignmentStrategies)
    # 7.
    if (lPossibleAssignments.empty?)
      # 7.1.
      # TODO: Get more info from the already tried paths tree
      return nil, [ [ lTask, 'Not enough resources' ] ]
    # 8.
    else
      lBestNote = nil
      lCurrentBestAssignment = nil
      # 8.1.
      lPossibleAssignments.each do |iPossibleAssignment|
        # 8.1.1.
        lAssignmentNote = evaluateSolution(iPossibleAssignment, lBestImpossibleAssignment, lAssignmentStrategies, iProject)
        # 8.1.2.
        if ((lBestNote == nil) or
            (lAssignmentNote > lBestNote))
          lCurrentBestAssignment = iPossibleAssignment
          lBestNote = lAssignmentNote
        end
      end
      if ($Debug)
        puts 'Final chosen assignment:'
        SolutionManager.displayAssignmentInfo(lCurrentBestAssignment, true)
      end
      # 8.2.
      return lCurrentBestAssignment, nil
    end
  end
  
  # Method that evaluate a possible solution (by comparing it with the utopic one), and gives a note about it.
  # Basically this method computes a distance between the 2 given assignment info.
  # The method adds notes given to each task. The task note takes into account:
  # * The distance between utopic and found start dates (pondered with the priority of the task)
  # * The distance in the durations (pondered with the priority of the task)
  # * The way resources are assigned (based on user preferences - assignment strategies)
  #
  # Parameters:
  # * *iSolution* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The possible solution
  # * *iUtopicSolution* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The utopic solution
  # * *iAssignmentStrategies* (<em>list<AssignmentStrategy></em>): The list of assignment strategies to consider
  # * *iProject* (<em>Project</em>): The project
  # Return:
  # * _Integer_: The note (the bigger note the worst solution)
  def self.evaluateSolution(iSolution, iUtopicSolution, iAssignmentStrategies, iProject)
    rNote = 0
    
    iSolution.each do |iTask, iTaskAssignmentInfo|
      lUtopicTaskAssignmentInfo = iUtopicSolution[iTask]
      # Distance of start dates
      lDistanceStartDates = (iTaskAssignmentInfo.MinStartDate - lUtopicTaskAssignmentInfo.MinStartDate)
      # Distance of durations
      lDistanceDurations = (iTaskAssignmentInfo.MinEndDate - iTaskAssignmentInfo.MinStartDate) - (lUtopicTaskAssignmentInfo.MinEndDate - lUtopicTaskAssignmentInfo.MinStartDate)
      # The dates distance is pondered with priority of the task.
      lDatesDistance = (lDistanceStartDates + lDistanceDurations)*iTask.Priority
      # Consider all assignment strategies measures
      # First find the maximal measure max. We will then report all the measures to its
      # scale for better precision.
      lMaxMeasure = nil
      iTaskAssignmentInfo.FinalAssignmentMeasures.each do |iAssignmentStrategy, iMeasure|
        if ((lMaxMeasure == nil) or
            (iMeasure[1] > lMaxMeasure))
          lMaxMeasure = iMeasure[1]
        end
      end
      # The total distance of the assignment strategies
      lASDistance = 0
      iTaskAssignmentInfo.FinalAssignmentMeasures.each do |iAssignmentStrategy, iMeasure|
        # iMeasure is not a distance, but a score. Therefore we have to compute the
        # difference with the max measure to get a distance.
        lASDistance += lMaxMeasure - (iMeasure[0]*lMaxMeasure)/iMeasure[1]
      end
      # Here we have:
      # - lDatesDistance: the distance of delays of dates. Biggest value is the maximal
      #   duration of the project multiplied by iTask.Priority*2.
      # - lASDistance: the distance of assignment strategies. Biggest value is the
      #   number of assignment strategies multiplied by lMaxMeasure.
      # Now we combine both to get a final note for this task.
      # First get the biggest maximal value and report both distances on this value.
      lMaxDatesDistance = (iProject.EndDate - iProject.StartDate)*iTask.Priority*2
      lMaxASDistance = iTaskAssignmentInfo.FinalAssignmentMeasures.size*lMaxMeasure
      lNormalizedASDistance = 0
      lNormalizedDatesDistance = 0
      lNormalizedMaxDistance = 0
      if (lMaxDatesDistance > lMaxASDistance)
        lNormalizedASDistance = (lASDistance*lMaxDatesDistance)/lMaxASDistance
        lNormalizedDatesDistance = lDatesDistance
        lNormalizedMaxDistance = lMaxDatesDistance
      else
        lNormalizedASDistance = lASDistance
        lNormalizedDatesDistance = (lDatesDistance*lMaxASDistance)/lMaxDatesDistance
        lNormalizedMaxDistance = lMaxASDistance
      end
      # Now we have to consider the importance of those distances by using coefficients.
      # These 2 values can be tuned also.
      lCoeffAS = 1
      lCoeffDates = 4
      rNote += (lNormalizedASDistance*lCoeffAS + lNormalizedDatesDistance*lCoeffDates)/(lNormalizedMaxDistance*(lCoeffAS+lCoeffDates))
    end
    # And now re divise rNote by the number of tasks. This way we can compare 2 notes
    # of assignments containing a different number of task.
    rNote = rNote/iSolution.size
    
    return rNote
  end
  
end
