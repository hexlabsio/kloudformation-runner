import io.hexlabs.kloudformation.module.s3.s3Website
import io.kloudformation.KloudFormation
import io.kloudformation.StackBuilder
import io.kloudformation.model.Output
import io.kloudformation.property.aws.certificatemanager.certificate.DomainValidationOption
import io.kloudformation.resource.aws.certificatemanager.certificate
import io.kloudformation.unaryPlus
import java.lang.IllegalArgumentException

const val certificateVariable = "InstallKloudFormationCertificate"
const val domain = "install.kloudformation.hexlabs.io"

class CertInUsEast1 : StackBuilder {
    override fun KloudFormation.create(args: List<String>) {
        val certificate = certificate(+"www.$domain") {
            subjectAlternativeNames(listOf(+domain))
            domainValidationOptions(listOf(DomainValidationOption(
                    domainName = +domain,
                    validationDomain = +domain
            )))
            validationMethod("DNS")
        }
        outputs(
            certificateVariable to Output(certificate.ref())
        )
    }
}

class Site : StackBuilder {
    override fun KloudFormation.create(args: List<String>) {
        val cert = System.getenv(certificateVariable) ?: throw IllegalArgumentException("No Certificate Variable")
        s3Website {
            s3Bucket {
                bucketName("install-kloudformation")
                websiteConfiguration {
                    indexDocument("install-kloudformation.sh")
                    errorDocument("install-kloudformation.sh")
                }
            }
            s3Distribution(
                    domain = +domain,
                    certificateArn = +cert
            )
        }
    }
}