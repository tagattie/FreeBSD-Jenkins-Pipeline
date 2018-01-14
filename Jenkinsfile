#! /usr/bin/env groovy

pipeline {
    agent any
    environment {
        // Configuration file (JSON)
        CONFIG='Config.json'
    }
    parameters {
        booleanParam(name: 'DOPOLL',
                     defaultValue: true,
                     description: 'If true, execute poll stage.')
        booleanParam(name: 'DOUPDATE',
                     defaultValue: true,
                     description: 'If true, execute update stage.')
        booleanParam(name: 'DOBUILD',
                     defaultValue: true,
                     description: 'If true, execute build stage.')
        booleanParam(name: 'FORCEBUILD',
                     defaultValue: false,
                     description: 'If true, execute build stage even when there are no updates.')
        booleanParam(name: 'DONTCLEAN',
                     defaultValue: false,
                     description: 'If true, don\'t clean source tree before building.')
        booleanParam(name: 'DOBUILDHOST',
                     defaultValue: true,
                     description: 'If true, execute build host stage.')
        booleanParam(name: 'DOBUILDIMAGE',
                     defaultValue: true,
                     description: 'If true, execute build host image stage.')
    }
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
                    archiveArtifacts 'FreeBSD-Manual-Build/*'
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
                        def buildPairs = distributeMapToPairs(buildMap)
                        buildSteps = buildPairs.collectEntries(
                            {
                                [it, transformIntoBuildStep(it[0], it[1])]
                            }
                        )
                        buildHostSteps = config.freebsd.hosts.findAll(
                            {
                                it.getValue().get('enabled')
                            }
                        ).collectEntries(
                            {
                                [it.getValue().get('hostname'), transformIntoBuildHostStep(it.getValue().get('hostname'))]
                            }
                        )
                        buildImageSteps = config.freebsd.hosts.findAll(
                            {
                                it.getValue().get('enabled')
                            }
                        ).findAll(
                            {
                                it.getValue().get('buildImage')
                            }
                        ).collectEntries(
                            {
                                [it.getValue().get('hostname'), transformIntoBuildImageStep(it.getValue().get('hostname'))]
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
                environment name: 'DOPOLL', value: 'true'
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
                environment name: 'DOUPDATE', value: 'true'
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

        // TODO: Parallelize these two stages.
        stage('Build world and generic kernel.') {
            when {
                environment name: 'DOBUILD', value: 'true'
            }
            steps {
                script {
                    parallel(buildSteps)
                }
            }
        }

        stage('Build host.') {
            when {
                environment name: 'DOBUILDHOST', value: 'true'
            }
            steps {
                script {
                    parallel(buildHostSteps)
                }
            }
        }

        stage('Build image.') {
            when {
                environment name: 'DOBUILDIMAGE', value: 'true'
            }
            steps {
                script {
                    parallel(buildImageSteps)
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
                    script: """
${WORKSPACE}/FreeBSD-Manual-Build/Poll.sh ${inputStr}
"""
                ).trim() as Integer
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
                    sh """
${WORKSPACE}/FreeBSD-Manual-Build/Update.sh ${inputStr}
"""
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
                FORCEBUILD) {
                if (DONTCLEAN) {
                    optionsAdd = "-d"
                }
                try {
                    sh """
${WORKSPACE}/FreeBSD-Manual-Build/Build.sh \\
    -h ${archStr}-${branchStr} \\
    ${optionsAdd} \\
    buildworld buildkernel
"""
                    currentBuild.description += " SUCCESS(build world & kernel:${branchStr}:${archStr})"
                } catch (Exception e) {
                    currentBuild.description += " FAILURE(build world & kernel:${branchStr}:${archStr})"
                    throw e
                }
            }
        }
    }
}

def transformIntoBuildHostStep(String hostStr) {
    return {
        timestamps {
            BRANCH=sh (
                returnStdout: true,
                script: "${WORKSPACE}/FreeBSD-Manual-Build/Branch.sh ${hostStr}"
            ).trim()
            if ((changed[BRANCH] > 0 && buildable[BRANCH]) ||
                FORCEBUILD) {
                if (DONTCLEAN) {
                    optionsAdd = "-d"
                }
                try {
                    // When no steps specified in config,
                    // do complete install including boot files.
                    // (Default)
                    if (!config.freebsd.hosts."${hostStr}".steps) {
                        def targets = "buildworld buildkernel installworld installkernel distribution"
                        sh """
${WORKSPACE}/FreeBSD-Manual-Build/Build.sh \\
    -h ${hostStr} \\
    -c ${WORKSPACE}/jenkins-conf.sh \\
    ${optionsAdd} \\
    ${targets}
${WORKSPACE}/FreeBSD-Manual-Build/InstallBoot.sh \\
    -h ${hostStr} \\
    -c ${WORKSPACE}/jenkins-conf.sh
"""
                    } else {
                        def targets = ""
                        config.freebsd.hosts."${hostStr}".steps.each {
                            targets += "${it}" + " "
                        }
                        sh """
${WORKSPACE}/FreeBSD-Manual-Build/Build.sh \\
    -h ${hostStr} \\
    -c ${WORKSPACE}/jenkins-conf.sh \\
    ${optionsAdd} \\
    ${targets}
"""
                    }
                    currentBuild.description += " SUCCESS(build ${hostStr})"
                } catch (Exception e) {
                    currentBuild.description += " FAILURE(build ${hostStr})"
                    throw e
                }
            }
        }
    }
}

def transformIntoBuildImageStep(String hostStr) {
    return {
        timestamps {
            BRANCH=sh (
                returnStdout: true,
                script: "${WORKSPACE}/FreeBSD-Manual-Build/Branch.sh ${hostStr}"
            ).trim()
            if ((changed[BRANCH] > 0 && buildable[BRANCH]) ||
                FORCEBUILD) {
                try {
                    if (config.freebsd.hosts."${hostStr}".buildImage) {
                        sh """
${WORKSPACE}/FreeBSD-Manual-Build/Image.sh \\
    -h ${hostStr} \\
    -c ${WORKSPACE}/jenkins-conf.sh
"""
                        currentBuild.description += " SUCCESS(build image ${hostStr})"
                    }
                } catch (Exception e) {
                    currentBuild.description += " FAILURE(build image ${hostStr})"
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
