import io.kloudformation.KloudFormation
import io.kloudformation.StackBuilder
import io.kloudformation.resource.s3.bucket

class Kloudformation: StackBuilder {
    override fun KloudFormation.create() {
        bucket {
            bucketName("kloudformation-runner")
        }
    }
}