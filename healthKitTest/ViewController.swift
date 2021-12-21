//
//  ViewController.swift
//  ConnectHealthKit
//
//  Created by Yong Jun Cha on 2021/11/24.
//

import UIKit
import HealthKit
import Combine

class ViewController: UIViewController {
    
    var query: HKStatisticsCollectionQuery?
    let healthStore = HKHealthStore()
    let cancellables : [AnyCancellable] = []
    private let stepCountSubject = PassthroughSubject<HKStatistics, Never>()
    private let distanceSubject = PassthroughSubject<HKQuantity, Never>()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if HKHealthStore.isHealthDataAvailable() {
            
            let healthStore = HKHealthStore()
            let readDataTypes : Set = [HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
                                       HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning)!
            ]
            
            healthStore.requestAuthorization(toShare: nil, read: readDataTypes) { (success, error) in
                if !success {
                    // Handle the error here.
                } else {
                    print("Authorized Success")
                            self.getStepCountPerDay(finishCompletion: {  })
                    
                }
            }
        }
    }
    
    func subscribeHealthKitSubject(finishCompletion: @escaping () -> Void) {
        let cancellable = stepCountSubject.zip(distanceSubject)
            .subscribe(on: DispatchQueue.global(qos: .userInteractive))
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .sink { stepCount, distance in
                print("START DATE \(stepCount.startDate)")
                print("STEP COUNT :: \(String(describing: stepCount.sumQuantity())) ")
                print("DISTANCE :: \(distance)")
                print("-------------------------------------------------------------------------------------------")
            }
        finishCompletion()
        print("HEALTHKIT DATA SUBSCRIBE FINISH")
    }
    
    // 날짜별 스탭카운트 얻기
    func getStepCountPerDay(finishCompletion: @escaping () -> Void){

        guard let sampleType = HKObjectType.quantityType(forIdentifier: .stepCount)
            else {
                return
        }
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.day = 1

        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.hour = 0
        let anchorDate = calendar.date(from: anchorComponents)

        let stepsCumulativeQuery = HKStatisticsCollectionQuery(quantityType: sampleType, quantitySamplePredicate: nil, options: .cumulativeSum, anchorDate: anchorDate!, intervalComponents: dateComponents
        )

        // Set the results handler
        stepsCumulativeQuery.initialResultsHandler = {query, results, error in
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -30, to: endDate, wrappingComponents: false)
            if let myResults = results{
                myResults.enumerateStatistics(from: startDate!, to: endDate as Date) { [self] statistics, stop in
                    if let quantity = statistics.sumQuantity(){
                        let date = statistics.startDate
                        let steps = quantity.doubleValue(for: HKUnit.count())
                        print("START DATE :: \(statistics.startDate)")
                        print("STEP COUNT :: \(steps)")
                        print("-------------------------------------------------------------")
                    }
                }
            } else {
                print("STEP COUNT DATA NIL")
            }
        }
        HKHealthStore().execute(stepsCumulativeQuery)
        finishCompletion()
    }
    
    // 날짜별 걸은 거리 얻기
    func getWalkingDistancePerDay(){

        guard let sampleType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
            else {
                return
        }
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.day = 1

        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.hour = 0
        let anchorDate = calendar.date(from: anchorComponents)

        let stepsCumulativeQuery = HKStatisticsCollectionQuery(quantityType: sampleType, quantitySamplePredicate: nil, options: .cumulativeSum, anchorDate: anchorDate!, intervalComponents: dateComponents
        )

        // Set the results handler
        stepsCumulativeQuery.initialResultsHandler = {query, results, error in
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -1, to: endDate, wrappingComponents: false)
            if let myResults = results{
                myResults.enumerateStatistics(from: startDate!, to: endDate as Date) { [self] statistics, stop in
                    if let quantity = statistics.sumQuantity(){
                        let date = statistics.startDate
                        let distance = quantity.doubleValue(for: HKUnit.meter())
                        print("\(date): Discance= \(distance)")
                        distanceSubject.send(quantity)
                    }
                } //end block
            } //end if let
        }
        HKHealthStore().execute(stepsCumulativeQuery)
    }
    
    
    ///  설정한 기간동안의 걸음 수를 조회할 수 있는 쿼리.
    /// - Parameter completion: cumulative parameter sum
    func getTodaysSteps(completion: @escaping (Double) -> Void) {
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: stepsQuantityType,
            quantitySamplePredicate: predicate,
            options: .separateBySource
        ) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                print("Step Zero")
                completion(0.0)
                return
            }
            print("result check \(result)")
            completion(sum.doubleValue(for: HKUnit.count()))
        }
        healthStore.execute(query)
    }
    
    
    
    /// Mark: -  한달의 걸음 수와 걸은 시간을 날짜별로 가져오는 함수
    func getOneMonthStepCountAndWalkingTimePerDay() {
        var realmWalking : [Walking] = []
        let sampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)
        let today = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: today)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: today, options: HKQueryOptions.strictEndDate)
        let query = HKSampleQuery.init(sampleType: sampleType!,
                                       predicate: predicate,
                                       limit: HKObjectQueryNoLimit,
                                       sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { (query, results, error) in
            
            var dateOneIndexBeforeBuffer : Date? = nil
            var walkingDataBuffer : Walking = Walking()
            var stepCountBuffer : Int = 0
            var walkingSecondBuffer : Double = 0.0
            
            print("------------------------------------------------------------------------------------")
            results?.compactMap{
                $0
            }.forEach{ stepCountInfo in
                
                
                // Apple Watch와 중복 계산을 막아준다.
                if !stepCountInfo.description.contains("Watch"){
                    // Day 구분을 위해 StartDate에서 시간을 지워준다.
                    let startDate = convertStringToDate(dateString: (convertDateToString(date: stepCountInfo.startDate, format: "yyMMdd")), format: "yyMMdd")
                    
                    // 하나 전 인덱스와 비교해준다.
                    if dateOneIndexBeforeBuffer != nil {
                        // 시작일이 전 인덱스의 시작일과 다르다면 날짜가 바뀐 것.
                        
                            print("RESULT :: \(stepCountInfo.description)")
                        if startDate < dateOneIndexBeforeBuffer! {
                            
                            // 날짜가 바뀌면 해당 날짜와, 해당 일의 걸음 수 걸음 시간 각각의 총 합을 객체에 넣어준다.
                            // 인덱스 (인덱스는 날짜로 선언한다 가변적인 데이터에 대응하기 위해 같은 날짜의 데이터는 Realm에서 Update & Insert를 진행한다.
                            walkingDataBuffer.id = dateOneIndexBeforeBuffer!.millisecondsSince1970
                            print("*** WALKING DATE PER CELL  :: \(walkingDataBuffer.id)")
                            
                            // 걸음 수
                            walkingDataBuffer.walkingCount = stepCountBuffer
                            print("*** TOTAL WALKING COUNT PER CELL  :: \(walkingDataBuffer.walkingCount)")
                            
                            // 운동 시간
                            walkingDataBuffer.walkingSecond = Int(round(walkingSecondBuffer))
                            print("*** TOTAL WALKING TIME PER CELL  :: \(walkingDataBuffer.walkingSecond)")
                            print("------------------------------------------------------------------------------------")
                            
                            // 리셋 버퍼 벨류
                            walkingSecondBuffer = 0.0
                            stepCountBuffer = 0
                            
                            // DB에 들어갈 객체에 넣어준다.
                            realmWalking.append(walkingDataBuffer)
                        }
                        
                    }
                    
                    // 걸은 시간
                    // 운동을 마친 시간과 시작 시간의 timeIntervalSinceReferenceDate 값을 빼주면 운동을 한 시간이 계산된다.
                    let walkingSecond = stepCountInfo.endDate.timeIntervalSince1970 - stepCountInfo.startDate.timeIntervalSince1970
                    
                    // 걸은 시간을 더해준다.
                    walkingSecondBuffer += walkingSecond
                    
                    // 걸음 수
                    let stepCount = Int(stepCountInfo.description.components(separatedBy: " count")[0])
                    
                    // 걸음 수를 더해준다.
                    stepCountBuffer += stepCount ?? 0
                    
                    // 다음 인덱스에서 확인할 수 있게 Date를 dateOneIndexBeforeBuffer 에 저장해준다.
                    dateOneIndexBeforeBuffer = startDate
                    
                    // Use this log if you needed
                    //                print("*")
                    //                print("* START DATE :: \(stepCountInfo.startDate)")
                    //                print("* FORMATTED DATE :: \(startDate)")
                    //                print("* WALKING COUNT :: \(stepCount)")
                    //                print("* WALKING HOUR :: \(walkingSecond)")
                    //                print("*")
                    //                print("------------------------------------------------------------------------------------")
                }
                
            }
            
        }
        healthStore.execute(query)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // HKSampleQuery with a nil predicate
    func testSampleQuery() {
        // Simple Step count query with no predicate and no sort descriptors
        let sampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)
        let query = HKSampleQuery.init(sampleType: sampleType!,
                                       predicate: nil,
                                       limit: HKObjectQueryNoLimit,
                                       sortDescriptors: nil) { (query, results, error) in
            print("All Step Count Result\(results)")
        }

        healthStore.execute(query)
    }


    // Fetches biologicalSex of the user, and date of birth.
    func testCharachteristic() {
        if try! healthStore.biologicalSex().biologicalSex == HKBiologicalSex.female {
            print("You are female")
        } else if try! healthStore.biologicalSex().biologicalSex == HKBiologicalSex.male {
            print("You are male")
        } else if try! healthStore.biologicalSex().biologicalSex == HKBiologicalSex.other {
            print("You are not categorised as male or female")
        }

        if #available(iOS 10.0, *) {
            try! print(healthStore.dateOfBirthComponents())
        } else {
            // Fallback on earlier versions
            do {
                let dateOfBirth = try healthStore.dateOfBirth()
                print(dateOfBirth)
            } catch let error {
                print("There was a problem fetching your data: \(error)")
            }
        }
    }

    // HKSampleQuery with a predicate
    func testSampleQueryWithPredicate() {
        let sampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)

        let today = Date()
        let startDate = Calendar.current.date(byAdding: .month, value: -1, to: today)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: today, options: HKQueryOptions.strictEndDate)

        let query = HKSampleQuery.init(sampleType: sampleType!,
                                       predicate: predicate,
                                       limit: HKObjectQueryNoLimit,
                                       sortDescriptors: nil) { (query, results, error) in

            results?.compactMap{ countStep in
                print("\(countStep.startDate)")
                print("\(countStep.endDate)")

            }
            print("Result ::: \(results)")
        }

        healthStore.execute(query)
    }







    // Sample query with a sort descriptor
      func testSampleQueryWithSortDescriptor() {
          let sampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)

          let today = Date()
          let startDate = Calendar.current.date(byAdding: .month, value: -1, to: today)

          let predicate = HKQuery.predicateForSamples(withStart: startDate, end: today, options: HKQueryOptions.strictEndDate)

          let query = HKSampleQuery.init(sampleType: sampleType!,
                                         predicate: predicate,
                                         limit: HKObjectQueryNoLimit,
                                         sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { (query, results, error) in
                                          print("Descriptor :: \(results)")
              results?.compactMap{
                  $0
              }.forEach{ stepCount in
                  // 데이트랑 일자를 계산
                  print("STEPCOUNT :: \(stepCount)")
                  print("START DATE :: \(stepCount.sampleType.description.count)")
                  print("START DATE :: \(stepCount.sampleType.description)")
              }
          }

          healthStore.execute(query)
      }

}

func updateUIFromStatistics(_ statisticsCollection: HKStatisticsCollection) {
    
}



public func convertStringToDate(dateString: String, format: String) -> Date {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    dateFormatter.locale = Locale(identifier: "ko_KR")
//    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    return dateFormatter.date(from: dateString)!
}

public func convertStringToDateNil(dateString: String, format: String) -> Date? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    dateFormatter.locale = Locale(identifier: "ko_KR")
//    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    return dateFormatter.date(from: dateString)
}

public func convertDateToString(date: Date, format: String) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    dateFormatter.locale = Locale(identifier: "ko_KR")
//    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    return dateFormatter.string(from: date)
}

public func getCustomedZeroDate() -> Date {
    let myDateComponents = DateComponents(year: 0001, month: 1, day: 1)
    let calendar = Calendar.current
    let myDate = calendar.date(from: myDateComponents)
    // 직접 데이트를 생성하기 때문에 nil일 경우가 없다.
    return myDate!
}



// DTO
struct Walking : Hashable {
    // Walking Date
    public var id : CLong = Date().millisecondsSince1970
    public var walkingCount : Int = 0
    public var walkingSecond : Int = 0
    public var timeStamp : Date = Date()
    
    public init() {}
}

extension Date {
    public var millisecondsSince1970 : CLong {
        return CLong((self.timeIntervalSince1970 * 1000.0))
    }
}


