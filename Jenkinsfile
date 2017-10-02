#! /usr/bin/env groovy

pipeline {
    agent any
    environment {
        // Configuration file (JSON)
        CONFIG='Config.json'
    }
    // parameters {
    // }
    // triggers {
    // }
    stages {
        stage('Checkout Jenkinsfile and other files.') {
            steps {
                timestamps {
                    checkout scm
                    archiveArtifacts 'Jenkinsfile'
                    archiveArtifacts '*.sh'
                    archiveArtifacts 'Config.json'
                }
            }
        }

        stage('Read config file and do some preparations.') {
            steps {
                timestamps {
                    script {
                        config = readJSON(file: "${CONFIG}")
                        changed = config.freebsd.branches.collectEntries(
                            {
                                [it, 0]
                            }
                        )
                        echo "changed (initial) = ${changed}"
                        buildable = config.freebsd.branches.collectEntries(
                            {
                                [it, true]
                            }
                        )
                        echo "buildable (initial) = ${buildable}"
                        pollSteps = config.freebsd.branches.collectEntries(
                            {
                                [it, transformIntoPollStep(it)]
                            }
                        )
                        updateSteps = config.freebsd.branches.collectEntries(
                            {
                                [it, transformIntoUpdateStep(it)]
                            }
                        )

                        def buildMap = config.freebsd.build
                        echo "buildMap = ${buildMap}"
                        def buildPairs = distributeMapToPairs(buildMap)
                        echo "buildPairs = ${buildPairs}"
                        buildSteps = buildPairs.collectEntries(
                            {
                                [it, transformIntoBuildStep(it[0], it[1])]
                            }
                        )
                        currentBuild.description += ' SUCCESS(config)'
                    }
                }
            }
            post {
                failure {
                    timestamps {
                        script {
                            currentBuild.description += ' FAILURE(config)'
                        }
                    }
                }
            }
        }

        stage('Poll SCM.') {
            when {
                environment name: 'doPoll', value: 'true'
            }
            steps {
                script {
                    parallel(pollSteps)
                }
            }
            post {
                always {
                    echo "changed = ${changed}"
                }
            }
        }

        stage('Update source tree.') {
            when {
                environment name: 'doUpdate', value: 'true'
            }
            steps {
                script {
                    parallel(updateSteps)
                }
            }
            post {
                always {
                    echo "buildable = ${buildable}"
                }
            }
        }

        stage('Build world and generic kernel.') {
            when {
                environment name: 'doBuild', value: 'true'
            }
            steps {
                script {
                    parallel(buildSteps)
                }
            }
        }
    }

    post {
        always {
            timestamps {
                echo "${changed}"
                echo "${buildable}"
            }
        }
    }
}

def transformIntoPollStep(String inputStr) {
    return {
        timestamps {
            try {
                changed[inputStr] = sh (
                    returnStdout: true,
                    script: "svnlite status -qu ${config.freebsd.srcDirs."${inputStr}"} | wc -l").trim() as Integer
                currentBuild.description += " SUCCESS(poll ${inputStr} ${changed["${inputStr}"]})"
            } catch (Exception e) {
                currentBuild.description += " FAILURE(poll ${inputStr})"
                throw e
            }
        }
    }
}

def transformIntoUpdateStep(String inputStr) {
    return {
        timestamps {
            if (changed[inputStr] > 0) {
                try {
                    sh "sudo svnlite update ${config.freebsd.srcDirs."${inputStr}"}"
                    currentBuild.description += " SUCCESS(update ${inputStr})"
                } catch (Exception e) {
                    buildable[inputStr] = false
                    currentBuild.description += " FAILURE(update ${inputStr})"
                    throw e
                }
            }
        }
    }
}

def transformIntoBuildStep(String branchStr, String archStr) {
    return {
        timestamps {
            if ((changed[branchStr] > 0 && buildable[branchStr]) ||
                "${forceBuild}" == "true") {
                try {
                    sh """
${WORKSPACE}/Build.sh \\
    ${config.freebsd.srcDirs."${branchStr}"} \\
    ${config.freebsd.objDirBase}/"${branchStr}" \\
    ${config.freebsd.archs."${archStr}".arch_m} \\
    ${config.freebsd.archs."${archStr}".arch_p} \\
    "" \\
    "" \\
    "" \\
    buildworld \\
    buildkernel
"""
                    currentBuild.description += " SUCCESS(build buildworld & buildkernel:${branchStr}:${archStr})"
                } catch (Exception e) {
                    currentBuild.description += " FAILURE(build buildworld & buildkernel:${branchStr}:${archStr})"
                    throw e
                }
            }
        }
    }
}

def distributeMapToPairs(Map buildMap) {
    def pairs = []
    buildMap.each {
        if (it.getValue().get('enabled') == true) {
            def branch = it.getValue().get('branch')
            def archs = it.getValue().get('archs')
            archs.each {
                def pair = [branch, it]
                pairs.push(pair)
            }
        }
    }
    return pairs
}
