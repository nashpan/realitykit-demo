import UIKit
import RealityKit
import ARKit


class ViewController: UIViewController {

    @IBOutlet var arView: ARView!
    @IBOutlet var messageLabel: RoundedLabel!
    
    @IBOutlet weak var addItem: UIButton!
    
    var intersection: simd_float4x4 = simd_float4x4(0)
    var physicsChanged: Bool = false
    
    @IBOutlet var raiseMotion: UIButton!
    var outsideAnchor: Furniture.Outside!
    
    var red: ModelEntity!
    var green: ModelEntity!
    var yellow: ModelEntity!
    
    var avPlayerLooper: AVPlayerLooper? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            let robot = try ModelEntity.load(named: "robot")

            // Place model on a horizontal plane.
            let anchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.15, 0.15])
            arView.scene.anchors.append(anchor)

            // 1. 加载usdz文件,导入的是一个Entity robot
            // 2. 手动生成一个包围盒，用来产生物理效果
            // 3. 将加载的Entity模型作为children添加到包围盒中
            let material = SimpleMaterial(color: .clear, isMetallic: true)
            let box = ModelEntity.init(mesh: .generateBox(size: 0.01), materials: [material])
            box.children.append(robot)
            
            box.generateCollisionShapes(recursive: true)
            box.physicsBody = PhysicsBodyComponent(massProperties: .default, material: .default, mode: .dynamic)
            
            
            robot.scale = [1, 1, 1] * 0.006

            anchor.children.append(box)
            
            // 在添加到场景中后播放动画才有效果，否则这一行代码将失效
            for anim in robot.availableAnimations {
                robot.playAnimation(anim.repeat(duration: .infinity), transitionDuration: 1.25, startsPaused: false)
            }
        } catch {
            fatalError("Failed to load asset.")
        }
 
        // 这里演示的是一种加载reality composer 工程文件的方式
//        outsideAnchor = try! Furniture.loadOutside()
//        arView.scene.anchors.append(outsideAnchor)
        
        // important!
        // 1.  .rcproject文件载入到app中会被转成.reality后缀的文件，bulid时可观察XCode上的构建信息
        // 2.  因此可以采用下面的，以.reality后缀去加载文件
        // 3.  下面的“box"是工程文件中的场景名称，"red", "yellow", "green"是场景中的实体名称，均来源于构建的.rcproject工程
        let realitySceneURL = createRealityURL(filename: "Furniture",
                                                     fileExtension: "reality",
                                                     sceneName: "box")
        let loadAnchor  = try! Entity.loadAnchor(contentsOf: realitySceneURL!)
        let entity = loadAnchor.findEntity(named: "red")

        red = loadAnchor.findEntity(named: "red")!.children.first as! ModelEntity
        yellow = loadAnchor.findEntity(named: "yellow")!.children.first as! ModelEntity
        green = loadAnchor.findEntity(named: "green")!.children.first as! ModelEntity
        
        // dynamic 和.kinematic 看效果即可知道它们的含义了
        red.generateCollisionShapes(recursive: true)
        red.physicsBody = PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.1, restitution: 0.7), mode: .dynamic)

        yellow.generateCollisionShapes(recursive: true)
        yellow.physicsBody = PhysicsBodyComponent(massProperties: .default, material: .default, mode: .dynamic)


        green.generateCollisionShapes(recursive: true)
        green.physicsBody = PhysicsBodyComponent(massProperties: .default, material: .default, mode: .kinematic)

        arView.installGestures(.translation, for: yellow)
        arView.installGestures(.all, for: green)
        arView.installGestures(.translation, for: red)
        arView.scene.anchors.append(loadAnchor)
        
    }
    
    func add_physics() {
        
    }
    
    func createRealityURL(filename: String,
                          fileExtension: String,
                          sceneName:String) -> URL? {
        // Create a URL that points to the specified Reality file.
        guard let realityFileURL = Bundle.main.url(forResource: filename,
                                                   withExtension: fileExtension) else {
            print("Error finding Reality file \(filename).\(fileExtension)")
            return nil
        }

        // Append the scene name to the URL to point to
        // a single scene within the file.
        let realityFileSceneURL = realityFileURL.appendingPathComponent(sceneName,
                                                                        isDirectory: false)
        return realityFileSceneURL
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        self.togglePeopleOcclusion()
    }

    @IBAction func onTap(_ sender: UITapGestureRecognizer) {
//        togglePeopleOcclusion()
        
        yellow.addForce([0, 0, -100], relativeTo: nil)
        let location = sender.location(in: self.arView)

        print("Intersection Point: (%.2f, %.2f, %.2f)",intersection.columns.3.x, intersection.columns.3.y, intersection.columns.3.z)
        
        if let entity = self.arView.entity(at: location) as? ModelEntity, entity.physicsBody?.mode == .dynamic {
            entity.addForce([0, 40, 0], relativeTo: nil)
        } else {
            // 这一段代码是记录点击屏幕的点与场景的交点，方面后续在该点添加物体
            let results = self.arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)
            if let firstResult = results.first {
                self.intersection = firstResult.worldTransform
                let anchor = AnchorEntity(world: intersection)

                
                let modelEntity = ModelEntity(mesh: generateMesh())
                anchor.addChild(modelEntity)
                modelEntity.generateCollisionShapes(recursive: true)
                modelEntity.physicsBody = PhysicsBodyComponent(massProperties: .default,
                                                              material: .default,
                                                                  mode: .static)
                // 这段代码演示的是将一张图片贴到一个平面上
//                var material = UnlitMaterial(color: .white)
//                let imageUrl = Bundle.main.url(forResource: "chihiro", withExtension: ".jpeg")
//                if let texture = try? TextureResource.load(contentsOf: imageUrl!) {
//                    var unlitMateril = UnlitMaterial()
//                    unlitMateril.baseColor = MaterialColorParameter.texture(texture)
//                    material = unlitMateril
//                }
//                modelEntity.model?.materials = [material]
                
                
                // 这里演示的是将一段视频放置到一个平面上进行播放
                let asset = AVURLAsset(url: Bundle.main.url(forResource: "windChimes", withExtension: ".mp4")!)
                let playerItem = AVPlayerItem(asset: asset)
//                let player = AVlayer()
//
//                if #available(iOS 14.0, *) {
//                    modelEntity.model?.materials = [VideoMaterial(avPlayer: player)]
//                } else {
//                    // Fallback on earlier versions
//                }
//                player.replaceCurrentItem(with: playerItem)
//                player.play()
                
                // 这里采用QueuePlayer是为了循环播放,上面的代码只会播放一次，当然，使用AVPlayer添加一个播放完的回调也可实现循环播放
                let queuePlayer = AVQueuePlayer()
                self.avPlayerLooper = AVPlayerLooper(
                    player: queuePlayer,
                    templateItem: playerItem
                )
                
                modelEntity.model?.materials = [VideoMaterial(avPlayer: queuePlayer)]
                queuePlayer.play()
                
                self.arView.installGestures(.all, for: modelEntity).forEach{recognizer in
                    recognizer.addTarget(arView, action: #selector(handleGesture(sender:)))
                }
                modelEntity.position.y = (modelEntity.model?.mesh.bounds.extents.y)! / 2
                
                arView.scene.anchors.append(anchor)
            }
        }
        
    }
    
    @objc func handleGesture(sender: UIGestureRecognizer){
        if let panGesture = sender as? EntityTranslationGestureRecognizer {
            switch sender.state {
            case .began:
                guard let modelEntity = panGesture.entity as? ModelEntity else { return }
                if modelEntity.physicsBody?.mode == .dynamic {
                    physicsChanged = true
                    modelEntity.physicsBody?.mode = .kinematic
                }
            case .ended:
                guard let modelEntity = panGesture.entity as? ModelEntity else { return }
                if physicsChanged {
                    physicsChanged = false
                    modelEntity.physicsBody?.mode = .dynamic
                }
            default: break
            }
        }
        if let pintchGesture = sender as? EntityScaleGestureRecognizer {
            print(pintchGesture.scale)
        }
        
        if let doubleFingerGesture = sender as? EntityRotationGestureRecognizer {
            print(doubleFingerGesture.rotation)
        }
    }
    
    
    func generateMesh() -> MeshResource {
//        return .generateBox(size: 0.05)
        return .generatePlane(width: 1.0, height: 1.0)
    }
    
    @IBAction func animation(_ sender: Any) {
        // 这里演示的是在.rcproject工程中添加动画，然后在Xcode中去监听触发这个动画
//        outsideAnchor.notifications.drumer.post()
        
    }
    @IBAction func additem(_ sender: Any) {
        do {
            let vase = try ModelEntity.load(named: "vase")

            let anchor = AnchorEntity(world: intersection)
            anchor.children.append(vase)
            arView.scene.anchors.append(anchor)
            vase.scale = [1, 1, 1] * 0.006

        } catch {
            fatalError("Failed to load asset.")
        }
    }
    
    
    // 人物遮挡的功能
    fileprivate func togglePeopleOcclusion() {
        guard let config = arView.session.configuration as? ARWorldTrackingConfiguration else {
            fatalError("Unexpectedly failed to get the configuration.")
        }
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) else {
            fatalError("People occlusion is not supported on this device.")
        }
        switch config.frameSemantics {
        case [.personSegmentationWithDepth]:
            config.frameSemantics.remove(.personSegmentationWithDepth)
            messageLabel.displayMessage("People occlusion off", duration: 1.0)
        default:
            config.frameSemantics.insert(.personSegmentationWithDepth)
            messageLabel.displayMessage("People occlusion on", duration: 1.0)
        }
        arView.session.run(config)
    }
}
