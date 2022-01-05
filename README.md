<img src="https://user-images.githubusercontent.com/60722292/146908489-734c8709-fe24-4c4b-af84-1b02669e766e.jpg" alt="SignUpOff" width="85%" height="85%"/></img>
# AppleHealthKitConnect
- Apple HealthKit의 쿼리를 테스트한 앱입니다. 
- HKStatisticsCollectionQuery, HKStatisticsQuery, HKSampleQuery, Characteristic 등을 테스트 했습니다. 
# 개발 동기 
- 프로젝트 QA진행 도중 HealthKit관련 개선을 담당하게 되었다. 
- 걸음수도 디바이스의 건강 앱과 일치하지 않았고, 권한을 거부했을 때 기능이 작동하지 않았다. 
# 개선 사항 및 리뷰 
- 애플의 권장사항 대로 권한을 거부하면 거부한대로 앱이 동작하게 만들었다.
- 결과적으로는 HKSampleQuery -> HKStatisticsCollectionQuery 변화를 주니 걸음수가 디바이스의 건강앱과 일치하게 되었다.
- 대부분 블로그들의 코드랩은 HKSampleQuery되어 있으나, 그렇게 구현하면 애플 워치나 기기가 여러개인 사용자에게선 큰 오류가 난다.
- 상세 리뷰는 기술 블로그를 참조 [TechBlog](https://velog.io/@kuruma-42/How-to-Connect-HealthKit-p974onx2)
