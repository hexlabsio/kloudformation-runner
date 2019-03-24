import io.kloudformation.KloudFormation
import io.kloudformation.StackBuilder
import io.kloudformation.Value
import io.kloudformation.function.plus
import io.kloudformation.model.KloudFormationTemplate
import io.kloudformation.model.KloudFormationTemplate.Builder.Companion.awsAccountId
import io.kloudformation.model.KloudFormationTemplate.Builder.Companion.awsNoValue
import io.kloudformation.model.KloudFormationTemplate.Builder.Companion.awsNotificationArns
import io.kloudformation.model.KloudFormationTemplate.Builder.Companion.awsPartition
import io.kloudformation.model.KloudFormationTemplate.Builder.Companion.awsRegion
import io.kloudformation.model.KloudFormationTemplate.Builder.Companion.awsStackId
import io.kloudformation.model.KloudFormationTemplate.Builder.Companion.awsStackName
import io.kloudformation.model.KloudFormationTemplate.Builder.Companion.awsUrlSuffix
import io.kloudformation.model.Output
import io.kloudformation.model.iam.Resource
import io.kloudformation.model.iam.action
import io.kloudformation.model.iam.policyDocument
import io.kloudformation.property.aws.certificatemanager.certificate.DomainValidationOption
import io.kloudformation.property.aws.cloudfront.distribution.CustomOriginConfig
import io.kloudformation.property.aws.cloudfront.distribution.DefaultCacheBehavior
import io.kloudformation.property.aws.cloudfront.distribution.DistributionConfig
import io.kloudformation.property.aws.cloudfront.distribution.ForwardedValues
import io.kloudformation.property.aws.cloudfront.distribution.Origin
import io.kloudformation.property.aws.cloudfront.distribution.ViewerCertificate
import io.kloudformation.resource.aws.certificatemanager.Certificate
import io.kloudformation.resource.aws.certificatemanager.certificate
import io.kloudformation.resource.aws.cloudfront.Distribution
import io.kloudformation.resource.aws.cloudfront.distribution
import io.kloudformation.resource.aws.s3.Bucket
import io.kloudformation.resource.aws.s3.BucketPolicy
import io.kloudformation.resource.aws.s3.bucketPolicy
import io.kloudformation.resource.aws.s3.bucket
import io.kloudformation.toYaml

enum class CertificationValidationMethod{ EMAIL, DNS }
enum class SslSupportMethod(val value: String){ SNI("sni-only"), VIP("vip") }
enum class HttpMethod(val value: String){ HTTP1_1("http1.1"), HTTP2("http2") }
enum class CloudfrontPriceClass(val value: String){ _100("PriceClass_100"), _200("PriceClass_200"), ALL("PriceClass_ALL") }

fun KloudFormation.certificate(
        domainName: String,
        certificateValidationMethod: CertificationValidationMethod = CertificationValidationMethod.DNS,
        certificateBuilder: Certificate.Builder.() -> Certificate.Builder = {this}) = certificate(+"www.$domainName"){
    subjectAlternativeNames(listOf(+domainName))
    domainValidationOptions(listOf(DomainValidationOption(
            domainName = +domainName,
            validationDomain = +domainName
    )))
    validationMethod(certificateValidationMethod.name)
    certificateBuilder()
}

fun KloudFormation.s3Website(
        domainName: String,
        indexDocument: String = "index.html",
        errorDocument: String = indexDocument,
        bucketName: String? = null,
        certificateValidationMethod: CertificationValidationMethod = CertificationValidationMethod.DNS,
        certificateBuilder: Certificate.Builder.() -> Certificate.Builder = {this},
        certificateReference: Value<String> = certificate(domainName,certificateValidationMethod, certificateBuilder).ref(),
        bucketBuilder: Bucket.Builder.()-> Bucket.Builder = {this},
        bucket: Bucket = bucket {
            accessControl(+"PublicRead")
            if(bucketName != null) bucketName(bucketName)
            websiteConfiguration {
                indexDocument(indexDocument)
                errorDocument(errorDocument)
            }
            bucketBuilder()
        },
        bucketPolicy: BucketPolicy = bucketPolicy(
                bucket = bucket.ref(),
                policyDocument = policyDocument {
                    statement(
                            action = action("s3:GetObject"),
                            resource = Resource(listOf(+"arn:aws:s3:::" + bucket.ref() + "/*"))
                    ) { allPrincipals() }
                }
        ),
        origin: Origin = Origin(
                id = +"s3Origin",
                domainName = bucket.ref() + +".s3-website-" + awsRegion + +".amazonaws.com",
                customOriginConfig = CustomOriginConfig(
                        originProtocolPolicy = +"http-only"
                )
        ),
        sslSupportMethod: SslSupportMethod = SslSupportMethod.SNI,
        httpMethod: HttpMethod = HttpMethod.HTTP2,
        priceClass: CloudfrontPriceClass = CloudfrontPriceClass._200,
        defaultCacheBehavior: DefaultCacheBehavior = DefaultCacheBehavior(
                allowedMethods = +listOf(+"GET", +"HEAD", +"OPTIONS"),
                forwardedValues = ForwardedValues(queryString = +true),
                targetOriginId = origin.id,
                viewerProtocolPolicy = +"redirect-to-https"
        ),
        distributionConfig: DistributionConfig = DistributionConfig(
                origins = listOf(origin),
                enabled = +true,
                aliases = +listOf(+"www.$domainName", +domainName),
                defaultCacheBehavior = defaultCacheBehavior,
                defaultRootObject = +indexDocument,
                priceClass = +priceClass.value,
                httpVersion = +httpMethod.value,
                viewerCertificate = ViewerCertificate(acmCertificateArn = certificateReference, sslSupportMethod = +sslSupportMethod.value)
        ),
        distributionBuilder: Distribution.Builder.() -> Distribution.Builder = {this},
        distribution: Distribution = distribution(
                distributionConfig = distributionConfig
        ){ distributionBuilder() }
) {
}

val certificateVariable = "InstallKloudFormationCertificate"

class CertInUsEast1: StackBuilder{
    override fun KloudFormation.create() {
        val certificate = certificate("install.kloudformation.hexlabs.io")
        outputs(
                certificateVariable to Output(certificate.ref(), export = Output.Export(+certificateVariable))
        )
    }
}

class Site: StackBuilder {
    override fun KloudFormation.create() {
        s3Website(
                domainName = "install.kloudformation.hexlabs.io",
                bucketName = "install-kloudformation",
                indexDocument = "install-kloudformation.sh",
                errorDocument = "install-kloudformation.sh",
                certificateReference = +"arn:aws:acm:us-east-1:662158168835:certificate/bbb425c8-c79b-40bb-80a1-02d00f764dba"
        )

    }
}